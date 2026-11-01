# GitHub Actions CI — Requirements

## Goal
Validate Pi Studio on fresh GitHub-hosted runners without local dependency checkouts or model credentials.

## Requirements
- **R1** — Run CI on pull requests, pushes to main, and manual dispatch.
- **R2** — Run PiUI tests and existing Python infrastructure/icon checks.
- **R3** — Run iOS native unit/UI tests and a Simulator Release build; build macOS Release without running paused macOS automation.
- **R4** — Consume public PiSDK 0.1.0 and Flux 2.0.1 as exact remote Swift package dependencies in PiUI and Xcode. Remove required dependency symlinks and local-checkout environment overrides; commit both resolved lockfiles.
- **R5** — Use read-only permissions, bounded execution, cancellation of superseded runs, and failure artifacts.
- **R6** — Document coverage and exclusions; do not deploy, alter branch protection, or push automatically.

## Assumptions
- The existing CI design's scope remains appropriate; explicit approval of the revised design is required before implementation.

## Implementation Plan
### S1 — Released Swift package dependencies
Description: Implement R4 in PiUI, Xcode and preparation; update both lockfiles and local setup documentation. Verify PiUI tests and native Release builds against the published packages.

### S2 — Reproducible GitHub Actions checks
Description: After S1, add the workflow and README guidance for R1–R3 and R5–R6. Validate workflow syntax and lightweight checks locally; confirm hosted execution only after an authorized push.

## Open Questions
None.
