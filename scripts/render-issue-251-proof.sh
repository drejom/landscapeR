#!/usr/bin/env bash

# Render the public, redacted deployment proof for issue #251. The source
# revision is explicit so the proof remains reproducible after this branch
# advances; the command must run from a clean checkout of that revision.

set -euo pipefail

source_revision=${LANDSCAPER_PROOF_SOURCE_REVISION:-}
[[ "$source_revision" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'LANDSCAPER_PROOF_SOURCE_REVISION must be a 40-character SHA\n' >&2
    exit 2
}
protocol_merge=${LANDSCAPER_K1_PROTOCOL_MERGE:-f668e1e0f49f66b8bd8c244ca6fb667a9b39d896}
proof_root=.github/landing-proof/issue-251
scratch_root=.scratch/issue-251-proof
mkdir -p "$scratch_root" "$proof_root"
rm -f "$scratch_root"/*.txt

for alias in cluster-a cluster-b; do
    LANDSCAPER_DEPLOY_SCRATCH=.scratch \
    scripts/deploy-k1-revised-acceptance.sh \
        --remote-host "$alias" \
        --remote-run-root /shared/run-root \
        --source-revision "$source_revision" \
        --protocol-merge "$protocol_merge" \
        --runner-merge "$source_revision" \
        --bioconductor-version 3.22 \
        --dry-run > "$scratch_root/$alias.txt"
done

archive_a=$(awk '/archive SHA-256:/ {print $3}' "$scratch_root/cluster-a.txt")
archive_b=$(awk '/archive SHA-256:/ {print $3}' "$scratch_root/cluster-b.txt")
preflight_a=$(awk '/preflight SHA-256:/ {print $3}' "$scratch_root/cluster-a.txt")
preflight_b=$(awk '/preflight SHA-256:/ {print $3}' "$scratch_root/cluster-b.txt")
[[ "$archive_a" = "$archive_b" && "$preflight_a" = "$preflight_b" ]] || {
    printf 'cluster aliases produced different deterministic bundle identities\n' >&2
    exit 1
}

if command -v shasum >/dev/null 2>&1; then
    payload_verifier_sha=$(git show "$source_revision:inst/extdata/k1-revised-acceptance-payload-digest.sh" | shasum -a 256 | awk '{print $1}')
else
    payload_verifier_sha=$(git show "$source_revision:inst/extdata/k1-revised-acceptance-payload-digest.sh" | sha256sum | awk '{print $1}')
fi

sed \
    -e 's/cluster-a/<cluster-ssh-alias>/g' \
    -e 's#/shared/run-root#<shared-run-root>#g' \
    "$scratch_root/cluster-a.txt" > "$proof_root/deployment-dry-run.txt"
cat >> "$proof_root/deployment-dry-run.txt" <<'EOF'

The same archive and preflight hashes were obtained for a second caller-supplied
cluster alias. Hostnames, shared paths, and credentials are intentionally absent
from this public proof. The preflight is not run on a login node: the printed
command is evaluated only from an active hprcc/rbiocverse Slurm session.
EOF

cat > "$proof_root/deployment-manifest.tsv" <<EOF
field	value
source_revision	$source_revision
protocol_merge	$protocol_merge
runner_merge	$source_revision
bioconductor_version	3.22
source_archive_sha256	$archive_a
payload_verifier_sha256	$payload_verifier_sha
preflight_sha256	$preflight_a
workflow	tracked local package -> scp -> ssh verification -> active hprcc/rbiocverse preflight -> tracked launcher
cluster_contract	one deployer; hprcc/rbiocverse own runtime defaults
session_boundary	preflight and launcher require active Slurm and rbiocverse markers
submission_boundary	prepare-only by default; --submit is explicit
scientific_claim	implementation proof only; no acceptance result is claimed
EOF
