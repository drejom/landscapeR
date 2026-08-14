# Immutable scientific-artifact publication

Scientific workflows publish through one internal filesystem module. The
module has a deliberately narrow responsibility: it turns a complete declared
payload into a verified, content-addressed directory through one atomic move.

The publication module owns:

- validation of safe, unique governed paths;
- exact agreement between the staged payload and its declaration;
- SHA-256 file digests and the exact two-column manifest;
- the content-addressed directory name derived from the adapter's scientific
  identity digest;
- cleanup after interrupted staging;
- one atomic move into the final address; and
- generic rejection of missing, duplicate, altered, or undeclared files.

Scientific adapters own everything that gives those files meaning. Each
adapter validates its typed scientific result before publication, writes the
declared payload, supplies claim status and scientific identity, and performs
semantic replay after generic verification. Input hashes and RNG identity are
caller-owned under ADR 0023. Runtime telemetry never enters scientific evidence
identity.

An adapter may exclude operational telemetry from its scientific identity
while retaining that telemetry as governed payload. Generic verification still
protects every declared byte. The adapter supplies the identity projection,
and semantic replay confirms that the stored scientific evidence reproduces it.
Stage 1 adapters and scheduler orchestration share the backend-independent
projections in `R/20a-stage1-scientific-identity.R`; the scientific layer does
not depend on the orchestration module.

The scientific adapters are mapped below. Their serialized files, public
publish and verify functions, scientific validators, plots, captions, and
claim language remain different. The shared module is not a generic
scientific-result type.

| Artifact family | Adapter entry point | Semantic verifier | Compatibility |
|---|---|---|---|
| Design-aware K=1 calibration | Module-specific calibration publisher | Module-specific calibration verifier | Existing governed payload remains unchanged |
| K=1 calibration outcomes | `publish_k1_calibration_outcomes()` | `verify_k1_calibration_outcomes()` | Existing `MANIFEST.tsv` artifacts remain valid |
| K=1 acceptance | Internal acceptance publisher used by the public runner | `verify_k1_acceptance_artifact()` | Both accepted artifact versions retain their governed payloads |
| Revised K=1 acceptance | Revised acceptance publisher | Revised acceptance verifier | Existing governed payload remains unchanged |
| Single-replicate Stage 1 benchmark | `write_stage1_benchmark_artifact()` | `verify_stage1_benchmark_artifact()` | Historical `hashes.csv` snapshots remain readable and verifiable; new artifacts use `MANIFEST.tsv` |
| Full Stage 1 evidence | Full benchmark publication workflow | `verify_stage1_evidence_artifact()` | Historical `hashes.csv` artifacts remain readable and verifiable; new artifacts use `MANIFEST.tsv` |

The single-replicate benchmark artifact remains diagnostic evidence. It does
not establish full-grid coverage, candidate selection, holdout assessment, or
a scientific claim. Its publisher nevertheless uses the same immutable
filesystem transaction because it creates a verified, content-addressed
artifact.

Existing artifacts retain their manifest and content-address formats. A
publisher encountering an existing address verifies it rather than replacing
it. Contributors should add a scientific adapter to this module instead of
copying staging, manifest, rename, or generic verification code.
