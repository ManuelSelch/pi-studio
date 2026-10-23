# GitHub Actions CI — Design

## Proposed Design

- **New:** `.github/workflows/ci.yml` runs on pull requests, pushes to `main`, and manual dispatch. Three independent jobs run on GitHub-hosted `macos-26` with Xcode 26.2:
  - Package: PiUI tests, icon checks, and Simulator-isolation checks.
  - iOS: native unit tests, UI tests, and Simulator Release build, executed serially.
  - macOS: native Release build only. Native macOS automation remains paused.
- **Reused:** existing preparation, package-test, app-test, build-root, and Simulator-isolation scripts. Each runner owns its dependencies and build products.
- Check out public dependency repositories under `.build/ci`, pinned to the current verified local revisions:
  - Pi Chat: `6fe0b54ddecc9faeaa7f13263559f2365576ac0e`.
  - Flux: `fdac8c435694c4e328273f9f18ce9d15fa1a27d1`.
- Pass `PI_SDK_PATH` pointing to Pi Chat’s `packages/pi-sdk` and `PI_FLUX_PATH` to preparation. Keep `.dependencies` as symlinks and build products under runner temporary storage.
- **Changed:** README documents coverage, dependency pins, and exclusions.

## Decisions & Trade-offs

- Reuse scripts instead of duplicating build logic. Preserve local dependency defaults; explicit CI checkouts make fresh runners reproducible without migrating package dependencies.
- Select Xcode 26.2 because the published runner inventory includes it and an iOS 26.2 iPhone 17 runtime. This differs from the documented local 26.1.1 baseline; print toolchain/runtime versions for diagnosis.
- Use commit-pinned actions, read-only permissions, no persisted checkout credentials, bounded timeouts, and cancellation of superseded runs. No secrets or privileged PR events.
- Capture logs with pipefail; upload failure logs and available `.xcresult` bundles with bounded retention, not all DerivedData.
- Separate runners avoid Simulator collisions but repeat preparation. Omit caching initially for simplicity.
- Exclude deployment, distribution signing, backend/model acceptance, and native macOS unit/UI execution. Do not change branch protection or push automatically.

## Verification

- Validate workflow syntax and expressions with actionlint.
- Run existing lightweight Python checks and shell syntax checks for affected scripts.
- Run permitted local package/build checks as practical; do not execute paused macOS automation.
- Confirm hosted-runner compatibility after an authorized push or PR. Local validation alone does not prove a successful GitHub Actions run.

## Open Questions

None.
