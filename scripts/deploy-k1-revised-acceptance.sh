#!/usr/bin/env bash

# Transfer and prepare the reviewed revised K=1 acceptance run on a supported
# cluster. The same entrypoint is used for both supported clusters: the caller
# supplies an SSH host alias and the cluster's rbiocverse configuration, while
# rbiocverse and hprcc resolve paths, images, libraries, partitions, and
# controllers on the remote system.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  scripts/deploy-k1-revised-acceptance.sh \
    --remote-host HOST \
    --remote-config /path/to/rbiocverse/cluster-config.sh \
    --remote-run-root /shared/run/root \
    [--source-revision SHA] [--protocol-merge SHA] [--runner-merge SHA] \
    [--bioconductor-version VERSION] [--submit] [--dry-run]

Without --submit the remote preflight installs and verifies the package and
stages the tracked run files, but does not submit acceptance rows. --dry-run
builds the local bundle and prints the SCP/SSH contract without contacting the
remote host.
USAGE
}

die() {
    printf 'deploy-k1-revised-acceptance: %s\n' "$1" >&2
    exit 2
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        die "neither shasum nor sha256sum is available"
    fi
}

remote_host=${LANDSCAPER_REMOTE_HOST:-}
remote_config=${RBIOCVERSE_CONFIG_REMOTE:-}
remote_run_root=${LANDSCAPER_RUN_ROOT:-}
source_revision=${LANDSCAPER_SOURCE_REVISION:-}
protocol_merge=${LANDSCAPER_K1_PROTOCOL_MERGE:-}
runner_merge=${LANDSCAPER_K1_RUNNER_MERGE:-}
bioconductor_version=${BIOCONDUCTOR_VERSION:-3.22}
submit=false
dry_run=false

while (($#)); do
    case "$1" in
        --remote-host) remote_host=${2:?missing value for --remote-host}; shift 2 ;;
        --remote-config) remote_config=${2:?missing value for --remote-config}; shift 2 ;;
        --remote-run-root) remote_run_root=${2:?missing value for --remote-run-root}; shift 2 ;;
        --source-revision) source_revision=${2:?missing value for --source-revision}; shift 2 ;;
        --protocol-merge) protocol_merge=${2:?missing value for --protocol-merge}; shift 2 ;;
        --runner-merge) runner_merge=${2:?missing value for --runner-merge}; shift 2 ;;
        --bioconductor-version) bioconductor_version=${2:?missing value for --bioconductor-version}; shift 2 ;;
        --submit) submit=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown argument: $1" ;;
    esac
done

[[ -n "$remote_host" ]] || die "--remote-host is required"
[[ -n "$remote_config" ]] || die "--remote-config is required"
[[ -n "$remote_run_root" ]] || die "--remote-run-root is required"
[[ "$remote_run_root" = /* ]] || die "--remote-run-root must be an absolute remote path"
[[ "$remote_run_root" != *[[:space:]]* ]] || die "remote paths may not contain whitespace"

if [[ -z "$source_revision" ]]; then
    source_revision=$(git rev-parse HEAD)
fi
[[ "$source_revision" =~ ^[0-9a-f]{40}$ ]] || die "source revision must be a 40-character lowercase SHA"
[[ "$protocol_merge" =~ ^[0-9a-f]{40}$ ]] || die "protocol merge must be a 40-character lowercase SHA"
[[ "$runner_merge" =~ ^[0-9a-f]{40}$ ]] || die "runner merge must be a 40-character lowercase SHA"
[[ "$source_revision" = "$runner_merge" ]] || die "source and runner revisions must match"
[[ "$protocol_merge" != "$runner_merge" ]] || die "protocol and runner revisions must differ"
[[ "$bioconductor_version" =~ ^[0-9]+\.[0-9]+$ ]] || die "Bioconductor version must look like 3.22"

git rev-parse --verify "$source_revision^{commit}" >/dev/null || die "source revision is not present"
git rev-parse --verify "$protocol_merge^{commit}" >/dev/null || die "protocol revision is not present"
git rev-parse --verify "$runner_merge^{commit}" >/dev/null || die "runner revision is not present"
if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree must be clean before packaging a reviewed revision"
fi

scratch_root=${LANDSCAPER_DEPLOY_SCRATCH:-.scratch}
mkdir -p "$scratch_root"
bundle_root=$(mktemp -d "$scratch_root/k1-revised-acceptance-deploy.XXXXXX")
cleanup() { rm -rf "$bundle_root"; }
trap cleanup EXIT

git archive --format=tar --prefix=landscapeR-source/ "$source_revision" \
    | tar -x -C "$bundle_root"
description_path="$bundle_root/landscapeR-source/DESCRIPTION"
sed -i.bak '/^Config\/landscapeR\/Revision:/d' "$description_path"
printf '\nConfig/landscapeR/Revision: %s\n' "$source_revision" >> "$description_path"
rm -f "$description_path.bak"
find "$bundle_root/landscapeR-source" -exec touch -t 197001010000 {} +
tar -cf - -C "$bundle_root" landscapeR-source \
    | gzip -n > "$bundle_root/landscapeR-source.tar.gz"
source_sha256=$(sha256_file "$bundle_root/landscapeR-source.tar.gz")
printf 'field\tvalue\nsource_revision\t%s\nprotocol_merge\t%s\nrunner_merge\t%s\nbioconductor_version\t%s\nsource_archive_sha256\t%s\n' \
    "$source_revision" "$protocol_merge" "$runner_merge" \
    "$bioconductor_version" "$source_sha256" > "$bundle_root/deployment-manifest.tsv"

cat > "$bundle_root/remote-preflight.R" <<'REMOTE_R'
args <- commandArgs(trailingOnly = TRUE)
deployment_abort <- function(message, cause = NULL) {
    stop(structure(
        list(message = as.character(message), cause = cause),
        class = c("landscapeR_deployment_error", "error", "condition")
    ))
}
if (length(args) != 7L) deployment_abort("remote preflight received the wrong arguments")

tryCatch({

source_archive <- args[[1L]]
run_root <- args[[2L]]
source_revision <- args[[3L]]
protocol_merge <- args[[4L]]
runner_merge <- args[[5L]]
library_path <- args[[6L]]
submit <- identical(args[[7L]], "true")

if (!dir.exists(library_path)) deployment_abort("configured shared R library is unavailable")
source_parent <- file.path(run_root, "landscapeR-source")
if (dir.exists(source_parent)) unlink(source_parent, recursive = TRUE, force = TRUE)
dir.create(source_parent, recursive = TRUE, showWarnings = FALSE)
utils::untar(source_archive, exdir = source_parent)
source_dir <- file.path(source_parent, "landscapeR-source")
if (!dir.exists(source_dir)) deployment_abort("source archive did not contain its expected root")

description_path <- file.path(source_dir, "DESCRIPTION")
description <- readLines(description_path, warn = FALSE)
revision <- sub("^Config/landscapeR/Revision:[[:space:]]*", "", description[
    grepl("^Config/landscapeR/Revision:", description)
])
if (length(revision) != 1L || !identical(revision[[1L]], source_revision)) {
    deployment_abort("source archive revision metadata did not match the reviewed source")
}

if (!requireNamespace("pak", quietly = TRUE)) {
    tryCatch(
        utils::install.packages(
            "pak", lib = library_path,
            repos = "https://r-lib.github.io/p/pak/stable/"
        ),
        error = function(condition) {
            deployment_abort(
                paste0("could not bootstrap pak in the configured shared library: ",
                       conditionMessage(condition)), condition
            )
        }
    )
}
if (!requireNamespace("pak", quietly = TRUE)) {
    deployment_abort("pak is unavailable after bootstrap in the configured shared library")
}
pak::pkg_install(
    c("targets@1.12.0", "crew@1.3.2", "crew.cluster@0.4.0",
      "github::cohmathonc/hprcc@0.2.3"),
    lib = library_path,
    upgrade = FALSE
)
pak::local_install(
    source_dir,
    lib = library_path,
    dependencies = TRUE,
    upgrade = FALSE
)

installed <- utils::packageDescription("landscapeR", lib.loc = library_path)
installed_revision <- unname(installed[["Config/landscapeR/Revision"]])
if (!identical(installed_revision, source_revision)) {
    deployment_abort("installed landscapeR revision did not match the verified package source")
}

targets_source <- system.file(
    "extdata", "k1-revised-acceptance-targets.R",
    package = "landscapeR", lib.loc = library_path
)
launcher_source <- system.file(
    "extdata", "k1-revised-acceptance-launch.sh",
    package = "landscapeR", lib.loc = library_path
)
if (!nzchar(targets_source) || !nzchar(launcher_source)) {
    deployment_abort("installed landscapeR is missing the reviewed acceptance profile")
}
copy_or_verify <- function(source, destination, label) {
    if (file.exists(destination)) {
        if (!identical(unname(tools::md5sum(source)),
                       unname(tools::md5sum(destination)))) {
            deployment_abort(paste0("run root contains a different ", label))
        }
        return(invisible(TRUE))
    }
    if (!file.copy(source, destination)) {
        deployment_abort(paste0("could not stage the installed ", label))
    }
}
copy_or_verify(targets_source, file.path(run_root, "_targets.R"), "targets profile")
copy_or_verify(launcher_source, file.path(run_root, "k1-revised-acceptance-launch.sh"), "launcher")
Sys.chmod(file.path(run_root, "k1-revised-acceptance-launch.sh"), mode = "0755")

write.table(
    data.frame(
        source_revision = source_revision,
        protocol_merge = protocol_merge,
        runner_merge = runner_merge,
        installed_revision = installed_revision,
        submission_requested = submit,
        stringsAsFactors = FALSE
    ),
    file = file.path(run_root, "deployment-preflight.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE
)

if (submit) {
    Sys.setenv(
        LANDSCAPER_K1_PROTOCOL_MERGE = protocol_merge,
        LANDSCAPER_K1_RUNNER_MERGE = runner_merge,
        LANDSCAPER_RUN_ROOT = run_root
    )
    status <- system2("bash", file.path(run_root, "k1-revised-acceptance-launch.sh"))
    if (!identical(status, 0L)) deployment_abort("tracked acceptance launcher failed")
}
}, error = function(condition) {
    if (inherits(condition, "landscapeR_deployment_error")) stop(condition)
    deployment_abort(
        paste0("remote preflight failed: ", conditionMessage(condition)), condition
    )
})
REMOTE_R

printf 'Prepared reviewed deployment bundle\n'
printf '  source revision: %s\n' "$source_revision"
printf '  protocol merge:  %s\n' "$protocol_merge"
printf '  runner merge:    %s\n' "$runner_merge"
printf '  archive SHA-256:  %s\n' "$source_sha256"
printf '  remote host:      %s\n' "$remote_host"
printf '  remote run root:  %s\n' "$remote_run_root"
printf '  submission:       %s\n' "$submit"

if "$dry_run"; then
    printf 'DRY RUN: would create %s/.landscapeR-incoming\n' "$remote_run_root"
    printf 'DRY RUN: scp archive, manifest, and preflight to %s:%s/.landscapeR-incoming/\n' "$remote_host" "$remote_run_root"
    printf 'DRY RUN: ssh %s to run rbiocverse preflight and the tracked Slurm launcher\n' "$remote_host"
    exit 0
fi

ssh "$remote_host" bash -s -- "$remote_run_root" <<'REMOTE_MKDIR'
set -euo pipefail
run_root=$1
mkdir -p "$run_root/.landscapeR-incoming"
REMOTE_MKDIR

scp -q "$bundle_root/landscapeR-source.tar.gz" \
    "$bundle_root/deployment-manifest.tsv" \
    "$bundle_root/remote-preflight.R" \
    "$remote_host:$remote_run_root/.landscapeR-incoming/"

ssh "$remote_host" bash -s -- \
    "$remote_run_root" "$remote_config" "$source_revision" "$protocol_merge" \
    "$runner_merge" "$bioconductor_version" "$submit" <<'REMOTE_RUN'
set -euo pipefail
run_root=$1
cluster_config=$2
source_revision=$3
protocol_merge=$4
runner_merge=$5
bioconductor_version=$6
submit=$7

source "$cluster_config"
cluster=$(validate_cluster)
library_path=$(get_library_path "$cluster" "$bioconductor_version")
container_path=$(get_container_path "$cluster" "$bioconductor_version")
[[ -d "$library_path" ]] || { echo "configured shared library is unavailable" >&2; exit 1; }
[[ -f "$container_path" ]] || { echo "configured rbiocverse container is unavailable" >&2; exit 1; }
load_singularity "$cluster"
export RBIOCVERSE_CONFIG="$cluster_config"
export R_LIBS_USER="$library_path"

incoming="$run_root/.landscapeR-incoming"
manifest="$incoming/deployment-manifest.tsv"
[[ -f "$manifest" ]] || { echo "deployment manifest is missing" >&2; exit 1; }
expected_source_sha=$(awk -F '\t' '$1 == "source_archive_sha256" {print $2}' "$manifest")
if command -v sha256sum >/dev/null 2>&1; then
    actual_source_sha=$(sha256sum "$incoming/landscapeR-source.tar.gz" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    actual_source_sha=$(shasum -a 256 "$incoming/landscapeR-source.tar.gz" | awk '{print $1}')
else
    echo "neither sha256sum nor shasum is available" >&2
    exit 1
fi
[[ -n "$expected_source_sha" && "$expected_source_sha" = "$actual_source_sha" ]] || {
    echo "source archive hash does not match the transferred manifest" >&2
    exit 1
}
for pair in \
    "source_revision:$source_revision" \
    "protocol_merge:$protocol_merge" \
    "runner_merge:$runner_merge"; do
    field=${pair%%:*}
    expected=${pair#*:}
    observed=$(awk -F '\t' -v key="$field" '$1 == key {print $2}' "$manifest")
    [[ "$observed" = "$expected" ]] || {
        echo "deployment manifest field $field does not match the requested revision" >&2
        exit 1
    }
done
preflight=$(printf '%q' "$incoming/remote-preflight.R")
archive=$(printf '%q' "$incoming/landscapeR-source.tar.gz")
run_root_q=$(printf '%q' "$run_root")
source_q=$(printf '%q' "$source_revision")
protocol_q=$(printf '%q' "$protocol_merge")
runner_q=$(printf '%q' "$runner_merge")
library_q=$(printf '%q' "$library_path")
submit_q=$(printf '%q' "$submit")
run_in_container "$bioconductor_version" \
    "Rscript --vanilla $preflight $archive $run_root_q $source_q $protocol_q $runner_q $library_q $submit_q"
REMOTE_RUN
