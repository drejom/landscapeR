#!/usr/bin/env python3
"""Build canonical Pogona analysis manifests from the audited master registry."""

from __future__ import annotations

import csv
import hashlib
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source_metadata" / "MASTER_pogona_sequencing_SLIM.csv"
SOURCE_SHA256 = "5a450ef02f148c2fc275b048dca58f51b72fbef0590509450c49a91c8ae147dc"

EXPERIMENTS = {
    "gsd_timecourse_28c": {
        "dataset": "GSD_RNAseq_v2",
        "expected_columns": 35,
        "expected_included": 33,
    },
    "early_urogenital_28c": {
        "dataset": "GSD_early_stage_RNAseq",
        "expected_columns": 17,
        "expected_included": 17,
    },
    "gonad_temperature": {
        "dataset": "Gonad_RNAseq",
        "expected_columns": 83,
        "expected_included": 76,
    },
}

FIELDS = [
    "experiment",
    "matrix_sample_id",
    "include",
    "exclusion_reason",
    "genotype",
    "temperature_c",
    "stage",
    "day",
    "tissue",
    "biological_unit",
    "source_group",
    "source_deg_id",
    "metadata_status",
    "source_library_keys",
    "source_specimen_ids",
    "source_pool_composition",
    "genotype_confidence",
    "temperature_confidence",
    "stage_confidence",
    "source_registry_refcodes",
    "defect_flag",
]


def matrix_samples(directory: Path) -> list[str]:
    def header(path: Path) -> list[str]:
        with path.open(encoding="utf-8") as handle:
            return handle.readline().rstrip("\n").split("\t")[2:]

    counts = header(directory / "gene_counts.tsv")
    tpm = header(directory / "gene_tpm.tsv")
    if counts != tpm:
        raise ValueError(f"count/TPM columns differ in {directory.name}")
    if len(counts) != len(set(counts)):
        raise ValueError(f"duplicate matrix columns in {directory.name}")
    return counts


def matrix_tokens(value: str) -> list[tuple[str, str]]:
    tokens = []
    for item in value.split(";"):
        item = item.strip()
        if not item or ":" not in item:
            continue
        dataset, sample = item.split(":", 1)
        tokens.append((dataset.strip(), sample.strip()))
    return tokens


def read_registry() -> list[dict[str, str]]:
    observed = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if observed != SOURCE_SHA256:
        raise ValueError(
            "master registry SHA-256 differs from the audited source: "
            f"expected {SOURCE_SHA256}, observed {observed}"
        )
    with SOURCE.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    keys = [row["library_key"] for row in rows]
    if len(keys) != len(set(keys)):
        raise ValueError("master registry contains duplicate library_key values")
    return rows


def registry_index(
    rows: list[dict[str, str]],
) -> dict[tuple[str, str], list[dict[str, str]]]:
    index: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        for dataset, sample in matrix_tokens(row["matrix_columns"]):
            index[(dataset, sample)].append(row)
    return index


def joined(rows: list[dict[str, str]], field: str) -> str:
    return "; ".join(row[field] for row in rows if row[field])


def distinct(rows: list[dict[str, str]], field: str) -> str:
    return "; ".join(sorted({row[field] for row in rows if row[field]}))


def canonical_stage(value: str) -> str:
    return value.replace("Stage ", "S").strip()


def common_row(
    experiment: str,
    sample_id: str,
    matches: list[dict[str, str]],
) -> dict[str, object]:
    pooled = any(
        row["pool_composition"] or row["specimen_id"].startswith("POOLED")
        for row in matches
    )
    return {
        "experiment": experiment,
        "matrix_sample_id": sample_id,
        "include": "false",
        "exclusion_reason": "",
        "genotype": distinct(matches, "genotype"),
        "temperature_c": distinct(matches, "incubation_temp_C"),
        "stage": canonical_stage(distinct(matches, "stage")),
        "day": distinct(matches, "embryonic_day"),
        "tissue": distinct(matches, "tissue"),
        "biological_unit": (
            "unresolved combined libraries"
            if len(matches) > 1
            else "declared pool of destructive samples"
            if pooled
            else "independent destructive sample"
        ),
        "source_group": distinct(matches, "published_group"),
        "source_deg_id": sample_id,
        "metadata_status": "",
        "source_library_keys": joined(matches, "library_key"),
        "source_specimen_ids": joined(matches, "specimen_id"),
        "source_pool_composition": joined(matches, "pool_composition"),
        "genotype_confidence": distinct(matches, "genotype__confidence"),
        "temperature_confidence": distinct(
            matches, "incubation_temp_C__confidence"
        ),
        "stage_confidence": distinct(matches, "stage__confidence"),
        "source_registry_refcodes": joined(matches, "registry_refcodes"),
        "defect_flag": distinct(matches, "defect_flag"),
    }


def exclude(
    row: dict[str, object],
    status: str,
    reason: str,
) -> dict[str, object]:
    row["metadata_status"] = status
    row["exclusion_reason"] = reason
    return row


def build_row(
    experiment: str,
    sample_id: str,
    matches: list[dict[str, str]],
) -> dict[str, object]:
    row = common_row(experiment, sample_id, matches)
    if not matches:
        return exclude(row, "registry_unmatched", "no master-registry mapping")
    if len(matches) > 1:
        return exclude(
            row,
            "registry_multiple_libraries",
            "multiple registry libraries map to one matrix column",
        )

    source = matches[0]
    defect = source["defect_flag"]
    if defect:
        return exclude(row, "registry_defect", defect)

    if experiment == "gsd_timecourse_28c":
        row["stage"] = ""
        row["tissue"] = source["tissue"] or "gonad"
        row["source_group"] = f"{row['genotype']}_{row['day']}"
        required = ("genotype", "temperature_c", "day")
    elif experiment == "early_urogenital_28c":
        row["tissue"] = "whole urogenital system"
        row["source_group"] = (
            f"{row['genotype']}_{row['temperature_c']}C_{row['stage']}"
        )
        required = ("genotype", "temperature_c", "stage")
    else:
        row["source_group"] = (
            f"{row['genotype']}_{row['temperature_c']}C_{row['stage']}"
        )
        required = ("genotype", "temperature_c", "stage", "tissue")
        if "body" in sample_id.lower() and source["tissue"].lower() == "gonad":
            return exclude(
                row,
                "registry_tissue_conflict",
                "matrix identifier says body but master registry says gonad",
            )

    if row["genotype"] not in {"ZZ", "ZW"}:
        return exclude(
            row,
            "registry_genotype_unresolved",
            f"unsupported or unresolved genotype: {row['genotype'] or 'missing'}",
        )
    missing = [field for field in required if not row[field]]
    if missing:
        return exclude(
            row,
            "registry_incomplete",
            "missing required registry fields: " + ", ".join(missing),
        )

    row["include"] = "true"
    row["metadata_status"] = "master_registry_matched"
    return row


def write_metadata(
    directory: Path,
    rows: list[dict[str, object]],
) -> None:
    ids = matrix_samples(directory)
    if [row["matrix_sample_id"] for row in rows] != ids:
        raise ValueError(f"metadata order does not match matrix in {directory.name}")
    with (directory / "sample_metadata.csv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def build_experiment(
    experiment: str,
    config: dict[str, object],
    index: dict[tuple[str, str], list[dict[str, str]]],
) -> None:
    directory = ROOT / experiment
    ids = matrix_samples(directory)
    if len(ids) != config["expected_columns"]:
        raise ValueError(
            f"{experiment} has {len(ids)} columns; "
            f"expected {config['expected_columns']}"
        )
    rows = [
        build_row(
            experiment,
            sample_id,
            index.get((str(config["dataset"]), sample_id), []),
        )
        for sample_id in ids
    ]
    included = sum(row["include"] == "true" for row in rows)
    if included != config["expected_included"]:
        raise ValueError(
            f"{experiment} has {included} included columns; "
            f"expected {config['expected_included']}"
        )
    write_metadata(directory, rows)


if __name__ == "__main__":
    registry = registry_index(read_registry())
    for experiment_name, experiment_config in EXPERIMENTS.items():
        build_experiment(experiment_name, experiment_config, registry)
