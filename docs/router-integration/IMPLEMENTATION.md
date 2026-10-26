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
- **S3:** Router is now the sole owner of settings presentation; the S2 synchronization
  bridge is gone.
  - `SettingsFeature.State` keeps only `savedEndpoint`, `draft`, `isSaving` and `error`.
    `isPresented`, `saveRequest`/`isSaving`-from-UUID and their actions are removed; a Save
    request carries no UUID and a new flow is admitted by the middleware (`.flowStarted`).
  - `SettingsMiddleware` takes the app-scoped `ModalRouter<AppRoute>`: it presents on Open
    (a duplicate open preserves the flow, draft and error), dismisses by captured flow
    identity on Cancel or successful persistence (including unchanged endpoints), keeps
    `canDismiss` in sync with saving, and holds one in-flight Save token so a duplicate
    Save cannot double-persist and an obsolete completion cannot dismiss a newer flow.
  - `Container.settingsModal` is the single cached modal scope shared by `settingsStore`
    and `AppContainer`; `SettingsPresentation.isPresented(in:)` keeps Router types out of the
    shared test support files the native unit target compiles without linking Router.
  - `AppContainer` only translates native dismissal to editing cleanup
    (`settingsFlowEnded`) and passes modal-derived presentation to `WorkspaceContainer` for
    Stop suppression; it no longer observes settings state to navigate. The workspace never
    inspects `SettingsFeature` for visibility.
  - No navigation-triggering success field or view-observer loop remains.
- **S4:** Regression verification of the new routing (evidence below). Existing workspace
  session tabs, overview surfaces, navigation and connection lifecycle are unchanged. No
  Router sources, original library folder or remote repository were modified.

## Verification
Run locally with Xcode 26.1.1 / Swift 6.2.1 (pipeline suites):
- PiUI: **94 tests in 21 suites passed**. New/updated coverage:
  `SettingsMiddlewareTests` (presentation, duplicate open, trimmed save + dismissal, invalid
  input, failure/retry, save outside presentation, saving guard observed during persistence,
  duplicate Save admission), `SettingsFeatureTests` (reduce-level flow), `AppContainerTests`
  (native dismissal cleanup, ignored while saving) and `SettingsIntegrationTests`
  (next-connection endpoint, invalid endpoint, duplicate open preserving the draft);
  `SessionDependenciesTests` asserts the router is cached per scope and shared with the store.
- Native iOS unit/integration: **4 tests in 1 suite passed** (3 settings integration
  scenarios, opt-in loopback acceptance skipped).
- Native macOS unit/integration: **4 tests in 1 suite passed**, same scenarios.
- Native iOS UI: **24 passed**, 0 failures — Cancel, swipe-dismiss/reopen, validation, Save,
  relaunch persistence and active-session preservation still hold with middleware-owned routing.
- Native macOS and iOS Simulator Release builds: **passed**.
- `git diff --check`: pending final check. No macOS desktop UI automation was run; native
  macOS interaction acceptance remains manual.

## Local-only dependency limitation
Run `bash scripts/prepare.sh` before opening Xcode in a fresh checkout/worktree.
Other machines can set `PI_ROUTER_PATH` to their modernized Router checkout.
Hosted CI currently cannot complete preparation because its workflow does not supply this
unpublished checkout. Publishing/pushing Router or provisioning a suitable checkout is
separate work; do not substitute the incompatible old public release.
