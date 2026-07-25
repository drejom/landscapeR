#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

mkdir -p \
    "$root/gsd_timecourse_28c" \
    "$root/early_urogenital_28c" \
    "$root/gonad_temperature"

copy_pair() {
    remote=$1
    local_dir=$2
    scp "gadi:$remote/salmon.merged.gene_counts.tsv" "$local_dir/gene_counts.tsv"
    scp "gadi:$remote/salmon.merged.gene_tpm.tsv" "$local_dir/gene_tpm.tsv"
}

copy_pair \
    /g/data/xl04/sw4662/GSD_RNAseq_v2/results/star_salmon \
    "$root/gsd_timecourse_28c"
copy_pair \
    /g/data/xl04/sw4662/GSD_early_stage_RNAseq/results/star_salmon \
    "$root/early_urogenital_28c"
copy_pair \
    /g/data/xl04/sw4662/Gonad_RNAseq/results/star_salmon \
    "$root/gonad_temperature"

(
    cd "$root"
    shasum -a 256 */gene_counts.tsv */gene_tpm.tsv > matrix-sha256.txt
)
