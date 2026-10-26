# GitHub Actions CI — Design

## Overview
Reuse existing scripts in three independent GitHub Actions jobs: package checks, iOS tests/build, and macOS Release build. Use released remote Swift packages instead of local SDK/Flux symlinks, consistently in PiUI and the native Xcode project.

## Components
| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| Packages / Xcode | [PiUI manifest](../../Packages/PiUI/Package.swift), [Xcode project](../../pi-studio.xcodeproj/project.pbxproj), both Package.resolved files | Changed | Exact remote SDK/Flux requirements and resolved revisions; SDK product identity follows repository name |
| CI | `.github/workflows/ci.yml` (proposed) | New | Triggers, job execution, failure artifacts |
| Build scripts | [prepare.sh](../../scripts/prepare.sh) | Changed | Resolve remote packages without creating symlinks or requiring local checkout paths |
| Build scripts | [test-package.sh](../../scripts/test-package.sh), [test-app.sh](../../scripts/test-app.sh) | Reused | Existing test/build commands |
| Documentation | [README](../../README.md) | Changed | Explain CI coverage, pins and exclusions |

Each job owns its checkout, SwiftPM dependency resolution and temporary build directory. No production application state changes.

## Runtime flow
1. A pull request, push to main or manual dispatch starts the workflow; superseded runs are cancelled.
2. Each job selects Xcode 26.2 on `macos-26` and sets a temporary `PI_STUDIO_BUILD_ROOT`.
3. Preparation resolves public remote packages. PiUI and Xcode require exactly PiSDK 0.1.0 and Flux 2.0.1; committed lockfiles record the resolved revisions.
4. Package job runs PiUI tests plus icon, Simulator-isolation and loopback-launcher Python checks. iOS job serially runs unit tests, UI tests and Simulator Release build. macOS job builds Release only.
5. Failures retain available logs and `.xcresult` bundles with bounded retention.

## Contracts & API changes
| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Developers / CI → preparation | Local checkouts and symlinks → remote package resolution | Removes PI_SDK_PATH / PI_FLUX_PATH wiring; no legacy fallback |
| Public packages → PiUI / Xcode | Local working trees → exact PiSDK 0.1.0 and Flux 2.0.1 | Public product/API usage unchanged; clean builds verify released compatibility |

## Decisions & Trade-offs
- Use exact released versions requested by the user: PiSDK 0.1.0 (`f0a1d5c49b2c1e4ba627353689fd8d5946380ec3`) and Flux 2.0.1 (`f5ec91329f3b42ff16fab57a378eb759e13cfd50`). Both public tags were confirmed. Flux 2.0.1 declares the required iOS 16 minimum. Factory's existing requirement remains unchanged.
- Do not delete ignored local dependency folders or modify the underlying dependency checkouts. Remove their requirement from tracked configuration and documentation.
- Runner inventory currently lists Xcode 26.2 and iPhone 17/iOS 26.2. Print selected toolchain/runtime versions for diagnosis; hosted execution remains unverified.
- Use commit-pinned actions, read-only permissions, no persisted credentials, bounded timeouts and no privileged PR events. Public dependencies require no additional secrets.
- Omit caching initially. Independent jobs repeat preparation but isolate Simulator/build products.
- Exclude deployment, signing for distribution, backend/model acceptance and native macOS unit/UI execution while automation is paused. Do not alter branch protection or push automatically.

## Verification
- Planned: actionlint, shell syntax validation and existing lightweight Python checks.
- Planned: resolve both lockfiles, verify their SDK/Flux versions, run PiUI tests and iOS/macOS Release builds against fetched packages, and check active build configuration no longer references dependency symlinks. No paused macOS automation.
- An authorized push or PR is needed to verify hosted execution; local validation cannot prove a green GitHub run.

## Open Questions
None.
