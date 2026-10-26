# Router Integration — Implementation

## Delivered
- **S1:** PiUI consumes the local Router library through ignored `.dependencies/router`.
  `scripts/prepare.sh` links the modernized checkout (verified at `87238d7`),
  accepts `PI_ROUTER_PATH`, rejects missing checkouts/non-symlink destinations,
  and preserves released SDK/Flux requirements and lockfiles.
- **S2:** `AppContainer` owns the settings modal router; the app installs it on both platforms.
  WorkspaceContainer exposes a settings callback instead of hosting the sheet.
  Flux retains draft/save/endpoint policy, with guarded, identity-based modal dismissal.
  Duplicate opens preserve the active flow and draft.
- Existing workspace session tabs, overview surfaces, navigation and connection lifecycle
  are unchanged. No Router sources, original library folder or remote repository were modified.

## Verification
Run locally with Xcode 26.1.1 / Swift 6.2.1:
- PiUI: **93 tests in 21 suites passed**, including five new app-routing tests.
  Tests exercise the production state/modal bridge without launching a Mac app.
- Infrastructure: **12 tests passed** across dependency/preparation (6), icons (1),
  Simulator isolation (4) and loopback-launcher (1).
- Native iOS unit/integration: **2 passed**, opt-in loopback acceptance skipped.
- Native iOS UI: **24 passed**, including new interactive-dismissal/draft-reset coverage
  and existing validation, Cancel, Save, relaunch and active-session settings scenarios.
- Native macOS Release and iOS Simulator Release builds: **passed**.
- `git diff --check`: passed.
- No macOS desktop UI automation was run. Native macOS interaction acceptance remains manual.

## Local-only dependency limitation
Run `bash scripts/prepare.sh` before opening Xcode in a fresh checkout/worktree.
Other machines can set `PI_ROUTER_PATH` to their modernized Router checkout.
Hosted CI currently cannot complete preparation because its workflow does not supply this
unpublished checkout. Publishing/pushing Router or provisioning a suitable checkout is
separate work; do not substitute the incompatible old public release.
