# Router Integration — Implementation

## Delivered
- **S1:** PiUI consumes released Router **2.0.0** (exact pin, `87238d7`) alongside the
  exact PiSDK 0.1.0/Flux 2.0.1 releases. The Xcode project references the same remote
  Router package and links its product to the app and native unit-test targets.
  `scripts/prepare.sh` only resolves the released packages (no local checkout, symlink or
  `PI_ROUTER_PATH`); both lockfiles pin all four dependencies.
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
    and `AppContainer`. Because the Xcode project now references and links the released
    Router product, shared test support files inspect the router directly.
  - `AppContainer` only translates native dismissal to editing cleanup
    (`settingsFlowEnded`) and passes modal-derived presentation to `WorkspaceContainer` for
    Stop suppression; it no longer observes settings state to navigate. The workspace never
    inspects `SettingsFeature` for visibility.
  - No navigation-triggering success field or view-observer loop remains.
- **S4:** Regression verification of the new routing (evidence below). Existing workspace
  session tabs, overview surfaces, navigation and connection lifecycle are unchanged. No
  Router sources or remote repository were modified.
- **Released-dependency migration:** the earlier local Router checkout is fully replaced by
  the public 2.0.0 release, so hosted CI preparation no longer needs an unpublished checkout.

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
- Dependency contract: **4 tests passed** (`scripts/test-released-dependencies.py`) —
  PiUI declares exact remote Router/PiSDK/Flux with factory-only local `Packages/PiUI`, the
  Xcode project matches, preparation resolves only released packages, and both lockfiles pin
  Router 2.0.0.
- `git diff --check`: passed. No macOS desktop UI automation was run; native macOS
  interaction acceptance remains manual.

## Released dependency wiring
Run `bash scripts/prepare.sh` before opening Xcode or testing on a fresh checkout/worktree;
SwiftPM then fetches Router 2.0.0, PiSDK 0.1.0, Flux 2.0.1 and FactoryKit. Both
`Package.resolved` files are checked in. No local Router checkout, `.dependencies` link or
path override is required, so hosted CI preparation is reproducible.
