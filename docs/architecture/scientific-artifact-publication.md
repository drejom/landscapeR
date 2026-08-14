# Immutable scientific-artifact publication

Scientific workflows publish through one internal filesystem module. The
module has a deliberately narrow responsibility: it turns a complete declared
payload into a verified, content-addressed directory through one atomic move.

The publication module owns:

- validation of safe, unique governed paths;
- exact agreement between the staged payload and its declaration;
- SHA-256 file digests and the exact two-column manifest;
- the content-addressed directory name;
- cleanup after interrupted staging;
- one atomic move into the final address; and
- generic rejection of missing, duplicate, altered, or undeclared files.

Scientific adapters own everything that gives those files meaning. Each
adapter validates its typed scientific result before publication, writes the
declared payload, supplies claim status and scientific identity, and performs
semantic replay after generic verification. Input hashes and RNG identity are
caller-owned under ADR 0023. Runtime telemetry never enters scientific evidence
identity.

The first concrete adapters are design-aware K=1 calibration and revised K=1
acceptance. Their serialized files, public publish and verify functions,
scientific validators, plots, captions, and acceptance language remain
different. The shared module is not a generic scientific-result type.

Existing artifacts retain their manifest and content-address formats. A
publisher encountering an existing address verifies it rather than replacing
it. Contributors should add a scientific adapter to this module instead of
copying staging, manifest, rename, or generic verification code.
