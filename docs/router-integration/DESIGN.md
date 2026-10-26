# Router Integration — Design

## Overview
Use local Router for settings presentation in a public AppContainer in PiUI. Router becomes the
sole owner of whether settings is presented; `SettingsMiddleware` drives the router and owns the
saving dismissal guard. Keep the settings Flux feature (editing/persistence only) and
workspace/session behavior; this is a composition refactor, not a navigation redesign.

S3 supersedes the earlier S2 synchronization bridge: `SettingsFeature.isPresented`, the UUID
save-request bookkeeping and `synchronizeSettings` are removed rather than extended. S4 verifies
the new routing through integration/UI scenarios.

## Components
| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| PiUI | [Package.swift](../../Packages/PiUI/Package.swift) | Changed | Consume local Router through ../../.dependencies/router |
| Scripts | [prepare.sh](../../scripts/prepare.sh) | Changed | Validate PI_ROUTER_PATH (default: existing modernized checkout), create ignored link, resolve packages |
| PiUI | AppContainer | Changed | Resolve the app-scoped modal router, host workspace/settings, and translate native dismissal to editing cleanup only |
| PiUI | [WorkspaceContainer](../../Packages/PiUI/Sources/PiUI/Workspace/WorkspaceContainer.swift) | Changed | Receive settings callback and modal-derived presentation; retain workspace/session effects and Stop suppression |
| PiUI | [SettingsFeature](../../Packages/PiUI/Sources/PiUI/Settings/App/SettingsFeature.swift) | Changed | Own draft, saving progress, validation/error and endpoint only; no visibility flag, no save UUID |
| PiUI | [SettingsMiddleware](../../Packages/PiUI/Sources/PiUI/Settings/Middleware/SettingsMiddleware.swift) | Changed | Present/dismiss through the injected router, admit at most one save, manage the dismissal guard |
| App | [pi_studioApp](../../pi-studio/pi_studioApp.swift) | Changed | Install AppContainer; preserve platform lifecycle handlers |

## Runtime flow
1. Workspace settings action dispatches .opened; SettingsMiddleware presents .settings through the
   app-scoped router (a duplicate open preserves the active flow and draft).
2. Editing, validation and saving stay in Flux; the middleware keeps flow.canDismiss in sync with
   the saving state and admits at most one save at a time.
3. Cancel dismisses the current flow by identity; a successful save dismisses the originating flow
   after persisting (including unchanged endpoints); failures leave it open with the draft.
4. Native (swipe/interactive) dismissal clears the router presentation and signals editing cleanup
   only (dispatch .cancelled). It never re-creates a two-way visibility loop; saving blocks it.

## Contracts & API changes
| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Router → PiUI | No dependency → local Router library | Local checkout required; no RouterDemo |
| App → PiUI | WorkspaceContainer() → AppContainer() | Entry changes; lifecycle semantics unchanged |
| AppContainer → WorkspaceContainer | Workspace owns opening → required onOpenSettings callback plus modal-derived presentation | Screen actions unchanged |
| Settings Flux → presentation | Boolean drives sheet → middleware drives app-scoped ModalRouter | SettingsFeature no longer owns presentation or save UUIDs |

## Decisions & Trade-offs
- Router alone owns presentation identity; Flux keeps only editing/persistence state. Middleware is
  the only component that presents, dismisses and sets canDismiss, so there is no visibility flag
  and no state-observation navigation loop.
- Save admission needs no UUID: the reducer marks isSaving on an accepted Save and the middleware
  holds a single in-flight save token, so a duplicate Save cannot double-persist and an obsolete
  completion cannot dismiss a newer flow.
- A real new flow resets draft/error; duplicate opens preserve both. The middleware distinguishes
  them by whether the scope is already presenting .settings.
- Do not introduce StackRouter/TabRouter without a present need or change overview surfaces.
- Local preparation intentionally replaces the all-remote guarantee for Router only. Preserve SDK/Flux pins; update dependency/preparation tests and setup guidance.
- Approved settings layout is unchanged; no mockup iteration is needed.

## Verification
- Script tests cover valid/missing Router paths and retained release pins; resolve PiUI/Xcode dependencies.
- Middleware/reducer tests cover duplicate admission, failure/retry, unchanged-endpoint success,
  guarded dismissal and presentation-identity safety; an app-routing test covers native dismissal
  cleanup.
- Semantic integration and native iOS UI scenarios cover Cancel, swipe-dismiss/reopen, duplicate
  opens, successful saves and active-session preservation, plus next-connection endpoint semantics.
- Run PiUI tests, iOS unit/settings UI checks and macOS/iOS Release builds. Workspace regressions
  preserve tabs/drafts.
- No macOS UI automation; interaction acceptance remains manual.

## Open Questions
None.
