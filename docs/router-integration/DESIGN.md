# Router Integration — Design

## Overview
Use local Router for settings presentation in a proposed public AppContainer in PiUI. Keep the settings Flux feature and workspace/session behavior; this is a composition refactor, not a navigation redesign.

## Components
| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| PiUI | [Package.swift](../../Packages/PiUI/Package.swift) | Changed | Consume local Router through ../../.dependencies/router |
| Scripts | [prepare.sh](../../scripts/prepare.sh) | Changed | Validate PI_ROUTER_PATH (default: existing modernized checkout), create ignored link, resolve packages |
| PiUI | AppContainer (proposed) | New | Own one @State modal router for the app content lifetime; host workspace/settings and bridge Flux state with modal lifecycle |
| PiUI | [WorkspaceContainer](../../Packages/PiUI/Sources/PiUI/Workspace/WorkspaceContainer.swift) | Changed | Receive settings callback; retain workspace/session effects and Stop suppression |
| PiUI | [SettingsFeature](../../Packages/PiUI/Sources/PiUI/Settings/App/SettingsFeature.swift), [SettingsContainer](../../Packages/PiUI/Sources/PiUI/Settings/SettingsContainer.swift) | Reused | Own draft, saving and endpoint outcomes; render existing UI |
| App | [pi_studioApp](../../pi-studio/pi_studioApp.swift) | Changed | Install AppContainer; preserve platform lifecycle handlers |

## Runtime flow
1. Workspace settings action calls AppContainer's callback, dispatching .opened to the settings store.
2. AppContainer observes settings state (including initial state), admits .settings through ModalRouter and synchronizes flow.canDismiss with !isSaving.
3. SettingsContainer continues editing, validation and saving through existing Flux actions/middleware.
4. Cancel or successful Save clears isPresented; AppContainer releases the guard and dismisses the current flow by identity. Failures leave it open.
5. Interactive dismissal clears the router presentation; AppContainer dispatches .cancelled only if settings remains open. Idempotent checks prevent synchronization loops. Saving blocks interactive dismissal.

## Contracts & API changes
| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Router → PiUI | No dependency → local Router library | Local checkout required; no RouterDemo |
| App → PiUI | WorkspaceContainer() → AppContainer() | Entry changes; lifecycle semantics unchanged |
| AppContainer → WorkspaceContainer | Workspace owns opening → required onOpenSettings callback | Update construction sites/previews; screen actions unchanged |
| Settings Flux → presentation | Boolean directly drives sheet → Boolean drives modal bridge | Existing actions/state retained; router owns presentation identity, not draft state |

## Decisions & Trade-offs
- Retain SettingsFeature.isPresented for middleware admission and existing tests. The app-level bridge derives modal presentation from it and translates native dismissal to Cancel; no second settings business-state store.
- Do not introduce StackRouter/TabRouter without a present need or change overview surfaces.
- Local preparation intentionally replaces the all-remote guarantee for Router only. Preserve SDK/Flux pins; update dependency/preparation tests and setup guidance.
- Approved settings layout is unchanged; no mockup iteration is needed.

## Verification
- Script tests cover valid/missing Router paths and retained release pins; resolve PiUI/Xcode dependencies.
- Exercise the real bridge through hosted SwiftUI tests or native settings drivers: open, duplicate requests, interactive dismissal, saving guard, failures, successful save and reopening.
- Run PiUI tests, iOS unit/settings UI checks and macOS/iOS Release builds. Existing settings integration verifies next-connection semantics; workspace regressions preserve tabs/drafts.
- No macOS UI automation; interaction acceptance remains manual. These are planned checks, not results.

## Open Questions
None.
