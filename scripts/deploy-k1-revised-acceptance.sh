#!/usr/bin/env bash

# Transfer and prepare the reviewed revised K=1 acceptance run on a supported
# cluster. The same entrypoint is used for both supported clusters: the caller
# supplies an SSH host alias and a cluster-visible run root. The staged
# preflight runs from an active hprcc/rbiocverse Slurm session, where
# hprcc/rbiocverse resolve paths, images, libraries, partitions, and controllers.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  scripts/deploy-k1-revised-acceptance.sh \
    --remote-host HOST \
    --remote-run-root /shared/run/root \
    [--source-revision SHA] [--protocol-merge SHA] [--runner-merge SHA] \
    [--bioconductor-version VERSION] [--submit] [--dry-run]

The deployer stages the reviewed bundle over SCP/SSH. Run the printed
preflight command from an active hprcc/rbiocverse Slurm session; hprcc then
resolves the cluster, library, container, bind, partition, and controller
details. Without --submit the preflight installs and verifies the package and
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
[[ -n "$remote_run_root" ]] || die "--remote-run-root is required"
[[ "$remote_host" =~ ^[A-Za-z0-9._@:-]+$ ]] || die "--remote-host contains unsafe shell characters"
[[ "$remote_run_root" = /* ]] || die "--remote-run-root must be an absolute remote path"
[[ "$remote_run_root" =~ ^/[A-Za-z0-9._/-]+$ ]] || \
    die "--remote-run-root contains unsafe shell characters"

if [[ -z "$source_revision" ]]; then
    source_revision=$(git rev-parse HEAD)
fi
[[ "$source_revision" =~ ^[0-9a-f]{40}$ ]] || die "source revision must be a 40-character lowercase SHA"
[[ "$protocol_merge" =~ ^[0-9a-f]{40}$ ]] || die "protocol merge must be a 40-character lowercase SHA"
[[ "$runner_merge" =~ ^[0-9a-f]{40}$ ]] || die "runner merge must be a 40-character lowercase SHA"
[[ "$source_revision" = "$runner_merge" ]] || die "source and runner revisions must match"
[[ "$protocol_merge" != "$runner_merge" ]] || die "protocol and runner revisions must differ"
[[ "$bioconductor_version" =~ ^[0-9]+\.[0-9]+$ ]] || die "Bioconductor version must look like 3.22"
command -v python3 >/dev/null 2>&1 || die "python3 is required for deterministic archive creation"

git rev-parse --verify "$source_revision^{commit}" >/dev/null || die "source revision is not present"
git rev-parse --verify "$protocol_merge^{commit}" >/dev/null || die "protocol revision is not present"
git rev-parse --verify "$runner_merge^{commit}" >/dev/null || die "runner revision is not present"
if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree must be clean before packaging a reviewed revision"
fi
if "$submit"; then
    git merge-base --is-ancestor "$source_revision" origin/main || {
        die "submission source revision must be an ancestor of origin/main"
    }
    git merge-base --is-ancestor "$protocol_merge" origin/main || {
        die "submission protocol revision must be an ancestor of origin/main"
    }
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
python3 - "$bundle_root/landscapeR-source" "$bundle_root/landscapeR-source.tar.gz" <<'PY'
import gzip
import pathlib
import sys
import tarfile

root = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
paths = [root, *sorted(root.rglob("*"), key=lambda path: path.relative_to(root).as_posix())]

with destination.open("wb") as raw:
    with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as archive:
            for path in paths:
                info = archive.gettarinfo(str(path), arcname=path.relative_to(root.parent))
                info.uid = 0
                info.gid = 0
                info.uname = ""
                info.gname = ""
                info.mtime = 0
                if info.isfile():
                    with path.open("rb") as payload:
                        archive.addfile(info, payload)
                else:
                    archive.addfile(info)
PY
source_sha256=$(sha256_file "$bundle_root/landscapeR-source.tar.gz")
payload_verifier_sha256=$(sha256_file "$bundle_root/landscapeR-source/inst/extdata/k1-revised-acceptance-payload-digest.sh")
printf 'field\tvalue\nsource_revision\t%s\nprotocol_merge\t%s\nrunner_merge\t%s\nbioconductor_version\t%s\nsource_archive_sha256\t%s\npayload_verifier_sha256\t%s\n' \
    "$source_revision" "$protocol_merge" "$runner_merge" \
    "$bioconductor_version" "$source_sha256" "$payload_verifier_sha256" > "$bundle_root/deployment-manifest.tsv"

cat > "$bundle_root/remote-preflight.R" <<'REMOTE_R'
args <- commandArgs(trailingOnly = TRUE)
deployment_abort <- function(message, cause = NULL) {
    stop(structure(
        list(message = as.character(message), cause = cause),
        class = c("landscapeR_deployment_error", "error", "condition")
    ))
}
if (length(args) != 9L) deployment_abort("remote preflight received the wrong arguments")

tryCatch({

source_archive <- args[[1L]]
run_root <- args[[2L]]
source_revision <- args[[3L]]
protocol_merge <- args[[4L]]
runner_merge <- args[[5L]]
bioconductor_version <- args[[6L]]
source_archive_sha256 <- args[[7L]]
payload_verifier_sha256 <- args[[8L]]
submit <- identical(args[[9L]], "true")
if (!grepl("^[0-9a-f]{64}$", source_archive_sha256)) {
    deployment_abort("remote preflight received an invalid source archive digest")
}
if (!grepl("^[0-9a-f]{64}$", payload_verifier_sha256)) {
    deployment_abort("remote preflight received an invalid payload verifier digest")
}
if (!nzchar(Sys.getenv("SLURM_JOB_ID")) || !nzchar(Sys.getenv("SINGULARITY_CONTAINER"))) {
    deployment_abort("remote preflight must run inside an active rbiocverse Slurm session")
}

if (!requireNamespace("hprcc", quietly = TRUE)) {
    deployment_abort("active Slurm session does not provide hprcc")
}
cluster <- tryCatch(
    hprcc::get_cluster(),
    error = function(condition) {
        deployment_abort("hprcc could not identify the active cluster", condition)
    }
)
if (!identical(cluster, "apollo") && !identical(cluster, "gemini")) {
    deployment_abort("hprcc identified an unsupported active cluster")
}
Sys.setenv(BIOCONDUCTOR_VERSION = bioconductor_version)
container_path <- tryCatch(
    getFromNamespace("singularity_container", "hprcc")(),
    error = function(condition) {
        deployment_abort("hprcc could not resolve the active rbiocverse container", condition)
    }
)
if (!is.character(container_path) || length(container_path) != 1L ||
    !nzchar(container_path) || !file.exists(container_path)) {
    deployment_abort("hprcc-selected rbiocverse container is unavailable")
}
library_path <- tryCatch(
    getFromNamespace("r_libs_site", "hprcc")(),
    error = function(condition) {
        deployment_abort("hprcc could not resolve the shared R library", condition)
    }
)
if (!is.character(library_path) || length(library_path) != 1L ||
    !nzchar(library_path) || !dir.exists(library_path)) {
    deployment_abort("hprcc-selected shared R library is unavailable")
}

if (!dir.exists(run_root) &&
    !dir.create(run_root, recursive = TRUE, showWarnings = FALSE)) {
    deployment_abort("could not create the configured deployment run root")
}
preflight_path <- file.path(run_root, "deployment-preflight.tsv")
preflight_lock <- paste0(preflight_path, ".lock")
if (!dir.create(preflight_lock, showWarnings = FALSE)) {
    deployment_abort("another deployment preflight is using this run root")
}
on.exit(unlink(preflight_lock, recursive = TRUE, force = TRUE), add = TRUE)
required_preflight_fields <- c(
    "source_revision", "protocol_merge", "runner_merge",
    "bioconductor_version", "source_archive_sha256",
    "payload_verifier_sha256", "installed_payload_sha256",
    "installed_revision", "submission_requested"
)
read_preflight <- function(path) {
    previous <- tryCatch(
        read.delim(path, stringsAsFactors = FALSE),
        error = function(condition) NULL
    )
    if (!is.data.frame(previous) || nrow(previous) != 1L ||
        !all(required_preflight_fields %in% names(previous))) {
        deployment_abort("existing deployment preflight marker is unreadable")
    }
    submission_state <- as.character(previous$submission_requested[[1L]])
    if (length(submission_state) != 1L ||
        !submission_state %in% c("TRUE", "FALSE")) {
        deployment_abort("existing deployment preflight submission state is invalid")
    }
    previous
}
if (file.exists(preflight_path)) {
    previous <- read_preflight(preflight_path)
    known_expected <- c(
        source_revision = source_revision,
        protocol_merge = protocol_merge,
        runner_merge = runner_merge,
        bioconductor_version = bioconductor_version,
        source_archive_sha256 = source_archive_sha256,
        payload_verifier_sha256 = payload_verifier_sha256
    )
    known_observed <- vapply(
        names(known_expected),
        function(field) as.character(previous[[field]][[1L]]),
        character(1L)
    )
    if (!identical(unname(known_observed), unname(known_expected))) {
        deployment_abort("run root contains a preflight for a different deployment identity")
    }
    recorded_payload <- as.character(previous$installed_payload_sha256[[1L]])
    recorded_revision <- as.character(previous$installed_revision[[1L]])
    if (!grepl("^[0-9a-f]{64}$", recorded_payload) ||
        !grepl("^[0-9a-f]{40}$", recorded_revision)) {
        deployment_abort("existing deployment preflight identity is invalid")
    }
    if (identical(as.character(previous$submission_requested[[1L]]), "TRUE")) {
        deployment_abort(
            "a submission is already recorded for this run root; use a new run root"
        )
    }
}
if (!dir.exists(library_path)) deployment_abort("hprcc-selected shared R library is unavailable")
source_parent <- file.path(run_root, "landscapeR-source")
if (dir.exists(source_parent)) unlink(source_parent, recursive = TRUE, force = TRUE)
if (!dir.create(source_parent, recursive = TRUE, showWarnings = FALSE)) {
    deployment_abort("could not create the remote source staging directory")
}
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
                    paste0("could not bootstrap pak in the hprcc-selected shared library: ",
                       conditionMessage(condition)), condition
            )
        }
    )
}
if (!requireNamespace("pak", quietly = TRUE)) {
    deployment_abort("pak is unavailable after bootstrap in the hprcc-selected shared library")
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
payload_digest_source <- file.path(
    source_dir, "inst", "extdata",
    "k1-revised-acceptance-payload-digest.sh"
)
if (!nzchar(targets_source) || !nzchar(launcher_source) ||
    !file.exists(payload_digest_source)) {
    deployment_abort("installed landscapeR is missing the reviewed acceptance profile")
}
observed_payload_verifier_sha256 <- digest::digest(
    payload_digest_source, algo = "sha256", file = TRUE
)
if (!identical(observed_payload_verifier_sha256, payload_verifier_sha256)) {
    deployment_abort("source payload verifier differs from the reviewed archive manifest")
}

payload_digest <- function(package_root, label) {
    output <- system2(
        "bash", c(payload_digest_source, package_root),
        stdout = TRUE, stderr = TRUE
    )
    status <- attr(output, "status")
    if (!is.null(status) && !identical(as.integer(status), 0L)) {
        deployment_abort(paste0("could not hash the ", label, " landscapeR payload"))
    }
    digest <- trimws(tail(output, 1L))
    if (length(digest) != 1L || !grepl("^[0-9a-f]{64}$", digest)) {
        deployment_abort(paste0("the ", label, " payload verifier returned no SHA-256 digest"))
    }
    digest
}

installed_description <- system.file(
    "DESCRIPTION", package = "landscapeR", lib.loc = library_path
)
if (!nzchar(installed_description)) {
    deployment_abort("installed landscapeR has no DESCRIPTION file")
}
installed_root <- dirname(installed_description)
installed_payload_sha256 <- payload_digest(installed_root, "installed")
reference_library <- tempfile("landscapeR-reference-library-")
if (!dir.create(reference_library, recursive = TRUE, showWarnings = FALSE)) {
    deployment_abort("could not create the reference package library")
}
on.exit(unlink(reference_library, recursive = TRUE, force = TRUE), add = TRUE)
reference_install <- system2(
    file.path(R.home("bin"), "R"),
    c(
        "CMD", "INSTALL", "--no-test-load",
        "-l", reference_library, source_dir
    ),
    stdout = TRUE, stderr = TRUE,
    env = paste0("R_LIBS_USER=", library_path)
)
reference_status <- attr(reference_install, "status")
if (!is.null(reference_status) && !identical(as.integer(reference_status), 0L)) {
    deployment_abort("fresh reference installation of the reviewed source failed")
}
reference_description <- system.file(
    "DESCRIPTION", package = "landscapeR", lib.loc = reference_library
)
reference_root <- dirname(reference_description)
if (!nzchar(reference_description) || !dir.exists(reference_root)) {
    deployment_abort("fresh reference installation produced no landscapeR package")
}
reference_payload_sha256 <- payload_digest(reference_root, "reference")
if (!identical(installed_payload_sha256, reference_payload_sha256)) {
    deployment_abort("installed landscapeR payload differs from a fresh reviewed-source installation")
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

recorded_value <- function(path, expected, label) {
    if (!file.exists(path)) deployment_abort(paste0("run root is missing the ", label))
    observed <- trimws(readLines(path, warn = FALSE))
    if (length(observed) != 1L || !identical(observed[[1L]], expected)) {
        deployment_abort(paste0("run root contains a different ", label))
    }
}
write_record <- function(path, value, label) {
    if (file.exists(path)) {
        recorded_value(path, value, label)
        return(invisible(TRUE))
    }
    temporary <- tempfile(paste0(".", basename(path), "-"), tmpdir = run_root)
    on.exit(unlink(temporary, force = TRUE), add = TRUE)
    writeLines(value, temporary)
    if (!file.rename(temporary, path)) {
        deployment_abort(paste0("could not stage the ", label))
    }
    invisible(TRUE)
}

if (file.exists(preflight_path)) {
    previous <- read_preflight(preflight_path)
    expected <- c(
        source_revision = source_revision,
        protocol_merge = protocol_merge,
        runner_merge = runner_merge,
        bioconductor_version = bioconductor_version,
        source_archive_sha256 = source_archive_sha256,
        payload_verifier_sha256 = payload_verifier_sha256,
        installed_payload_sha256 = installed_payload_sha256,
        installed_revision = installed_revision
    )
    observed <- vapply(
        names(expected),
        function(field) as.character(previous[[field]][[1L]]),
        character(1L)
    )
    if (!identical(unname(observed), unname(expected))) {
        deployment_abort("run root contains a preflight for a different deployment identity")
    }
    if (identical(as.character(previous$submission_requested[[1L]]), "TRUE")) {
        deployment_abort(
            "a submission is already recorded for this run root; use a new run root"
        )
    }
}
copy_or_verify(targets_source, file.path(run_root, "_targets.R"), "targets profile")
copy_or_verify(launcher_source, file.path(run_root, "k1-revised-acceptance-launch.sh"), "launcher")
copy_or_verify(
    payload_digest_source,
    file.path(run_root, "k1-revised-acceptance-payload-digest.sh"),
    "payload verifier"
)
Sys.chmod(file.path(run_root, "k1-revised-acceptance-launch.sh"), mode = "0755")
Sys.chmod(file.path(run_root, "k1-revised-acceptance-payload-digest.sh"), mode = "0755")
write_record(
    file.path(run_root, "landscapeR-payload-sha256.txt"),
    installed_payload_sha256,
    "payload identity"
)
write_record(
    file.path(run_root, "landscapeR-payload-verifier-sha256.txt"),
    payload_verifier_sha256,
    "payload verifier identity"
)

preflight_temporary <- tempfile(".deployment-preflight-", tmpdir = run_root)
on.exit(unlink(preflight_temporary, force = TRUE), add = TRUE)
write.table(
    data.frame(
        source_revision = source_revision,
        protocol_merge = protocol_merge,
        runner_merge = runner_merge,
        bioconductor_version = bioconductor_version,
        source_archive_sha256 = source_archive_sha256,
        payload_verifier_sha256 = payload_verifier_sha256,
        installed_payload_sha256 = installed_payload_sha256,
        installed_revision = installed_revision,
        submission_requested = submit,
        stringsAsFactors = FALSE
    ),
    file = preflight_temporary,
    sep = "\t", quote = FALSE, row.names = FALSE
)
if (!file.rename(preflight_temporary, preflight_path)) {
    deployment_abort("could not atomically record the deployment preflight")
}

if (submit) {
    Sys.setenv(
        LANDSCAPER_K1_PROTOCOL_MERGE = protocol_merge,
        LANDSCAPER_K1_RUNNER_MERGE = runner_merge,
        LANDSCAPER_RUN_ROOT = run_root,
        BIOCONDUCTOR_VERSION = bioconductor_version,
        LANDSCAPER_PAYLOAD_SHA256 = installed_payload_sha256,
        LANDSCAPER_PAYLOAD_VERIFIER = file.path(
            run_root, "k1-revised-acceptance-payload-digest.sh"
        ),
        LANDSCAPER_PAYLOAD_VERIFIER_SHA256 = payload_verifier_sha256
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

preflight_sha256=$(sha256_file "$bundle_root/remote-preflight.R")
printf 'preflight_sha256\t%s\n' "$preflight_sha256" >> "$bundle_root/deployment-manifest.tsv"

printf 'Prepared reviewed deployment bundle\n'
printf '  source revision: %s\n' "$source_revision"
printf '  protocol merge:  %s\n' "$protocol_merge"
printf '  runner merge:    %s\n' "$runner_merge"
printf '  archive SHA-256:  %s\n' "$source_sha256"
printf '  preflight SHA-256: %s\n' "$preflight_sha256"
printf '  remote host:      %s\n' "$remote_host"
printf '  remote run root:  %s\n' "$remote_run_root"
printf '  submission:       %s\n' "$submit"

if "$dry_run"; then
    printf 'DRY RUN: would create %s/.landscapeR-incoming\n' "$remote_run_root"
    printf 'DRY RUN: scp archive, manifest, and preflight to %s:%s/.landscapeR-incoming/\n' "$remote_host" "$remote_run_root"
    printf 'DRY RUN: run the printed preflight command from an active hprcc/rbiocverse Slurm session\n'
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
    "$remote_run_root" "$source_revision" "$protocol_merge" "$runner_merge" \
    "$bioconductor_version" "$source_sha256" "$payload_verifier_sha256" \
    "$preflight_sha256" "$submit" <<'REMOTE_RUN'
set -euo pipefail
run_root=$1
source_revision=$2
protocol_merge=$3
runner_merge=$4
bioconductor_version=$5
trusted_source_sha=$6
trusted_payload_verifier_sha=$7
trusted_preflight_sha=$8
submit=$9

incoming="$run_root/.landscapeR-incoming"
manifest="$incoming/deployment-manifest.tsv"
[[ -f "$manifest" ]] || { echo "deployment manifest is missing" >&2; exit 1; }
[[ "$trusted_source_sha" =~ ^[0-9a-f]{64}$ ]] || {
    echo "trusted source archive hash is invalid" >&2
    exit 1
}
[[ "$trusted_payload_verifier_sha" =~ ^[0-9a-f]{64}$ ]] || {
    echo "trusted payload verifier hash is invalid" >&2
    exit 1
}
[[ "$trusted_preflight_sha" =~ ^[0-9a-f]{64}$ ]] || {
    echo "trusted preflight hash is invalid" >&2
    exit 1
}
manifest_source_sha=$(awk -F '\t' '$1 == "source_archive_sha256" {print $2}' "$manifest")
manifest_payload_verifier_sha=$(awk -F '\t' '$1 == "payload_verifier_sha256" {print $2}' "$manifest")
manifest_preflight_sha=$(awk -F '\t' '$1 == "preflight_sha256" {print $2}' "$manifest")
if command -v sha256sum >/dev/null 2>&1; then
    actual_source_sha=$(sha256sum "$incoming/landscapeR-source.tar.gz" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    actual_source_sha=$(shasum -a 256 "$incoming/landscapeR-source.tar.gz" | awk '{print $1}')
else
    echo "neither sha256sum nor shasum is available" >&2
    exit 1
fi
[[ "$trusted_source_sha" = "$actual_source_sha" && \
    "$manifest_source_sha" = "$trusted_source_sha" ]] || {
    echo "source archive hash does not match the trusted local identity" >&2
    exit 1
}
archive_verifier_sha=$(tar -xOf "$incoming/landscapeR-source.tar.gz" \
    landscapeR-source/inst/extdata/k1-revised-acceptance-payload-digest.sh \
    | { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; } \
    | awk '{print $1}')
[[ "$trusted_payload_verifier_sha" = "$archive_verifier_sha" && \
    "$manifest_payload_verifier_sha" = "$trusted_payload_verifier_sha" ]] || {
    echo "payload verifier hash does not match the trusted local identity" >&2
    exit 1
}
actual_preflight_sha=$(if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$incoming/remote-preflight.R"
else
    shasum -a 256 "$incoming/remote-preflight.R"
fi | awk '{print $1}')
[[ "$trusted_preflight_sha" = "$actual_preflight_sha" && \
    "$manifest_preflight_sha" = "$trusted_preflight_sha" ]] || {
    echo "remote preflight hash does not match the trusted local identity" >&2
    exit 1
}
for pair in \
    "source_revision:$source_revision" \
    "protocol_merge:$protocol_merge" \
    "runner_merge:$runner_merge" \
    "bioconductor_version:$bioconductor_version"; do
    field=${pair%%:*}
    expected=${pair#*:}
    observed=$(awk -F '\t' -v key="$field" '$1 == key {print $2}' "$manifest")
    [[ "$observed" = "$expected" ]] || {
        echo "deployment manifest field $field does not match the requested revision" >&2
        exit 1
    }
done
printf 'REMOTE PREFLIGHT: run from an active hprcc/rbiocverse Slurm session:\n'
printf '  cd %q && Rscript --vanilla %q %q %q %q %q %q %q %q %q %q\n' \
    "$run_root" "$incoming/remote-preflight.R" \
    "$incoming/landscapeR-source.tar.gz" "$run_root" "$source_revision" \
    "$protocol_merge" "$runner_merge" "$bioconductor_version" \
    "$trusted_source_sha" "$trusted_payload_verifier_sha" "$submit"
REMOTE_RUN
