# Router Integration — Requirements

## Goal
Use the modernized local Router in Pi Studio/Pocket and move settings presentation out of the workspace without changing the interface. Complete the integration by making Router the sole owner of settings presentation, removing SettingsFeature.isPresented and the two-way synchronization bridge.

## Requirements
- **R1** — PiUI consumes the Router library from the existing local router-modernized checkout. Do not publish or copy library sources.
- **R2** — An app-level container hosts settings with ModalRouter/ModalRouterView on macOS and iOS. Workspace requests settings through a callback.
- **R3** — Preserve draft reset, validation, persistence, Cancel, successful-save dismissal, interactive dismissal and the saving dismissal guard. Failed saves remain visible; saved endpoints apply only to the next explicit connection.
- **R4** — Preserve session selection, tabs, drafts, transcript, connection lifecycle and Stop suppression while settings is visible. Do not replace session tabs with TabRouter or introduce unused stacks.
- **R5** — Preserve existing SDK/Flux release pins. Document local Router preparation and fail clearly if unavailable. Keep external build roots and the macOS automation restriction.
- **R6** — Router alone determines whether settings is presented. Remove SettingsFeature.State.isPresented, synchronizeSettings and the two-way presentation synchronization loop. Do not replace the field with another visibility flag in Flux.
- **R7** — SettingsFeature owns editing and persistence state only: saved endpoint, draft, validation/error and save progress/outcome. Beginning a new settings flow resets its draft/error; duplicate open requests preserve the current flow and edits. Cancel and interactive dismissal discard unsaved edits without persisting them. Neither can dismiss while saving.
- **R8** — Save completion must distinguish success from failure and belong to its originating request/flow. Successful Save dismisses only that flow, including when the endpoint is unchanged; failures retain the draft and error in the open flow. Duplicate or obsolete completions must not dismiss a newer flow or overwrite newer edits. Save admission must remain guarded without relying on a presentation flag in SettingsFeature.
- **R9** — Workspace Stop suppression derives from actual modal presentation supplied by app-level composition, not settings business state. Workspace must not inspect SettingsFeature to determine visibility. Preserve the existing pure screen callback/value boundary.
- **R10** — Update reducer, middleware, app-routing and semantic integration drivers to assert editing outcomes separately from Router presentation. Cover cancellation/reopening, duplicate opens, saving guards, failed saves, unchanged-endpoint success, obsolete completion and active-session preservation; verify native iOS dismissal wiring and both platform builds.

## Assumptions
- First integration covers settings only; session overview surfaces and phone navigation remain unchanged.
- Use an ignored .dependencies/router link with a PI_ROUTER_PATH override so worktrees need not share the original folder layout.

## Implementation Plan
### S1 — Local Router Dependency
Description: Delivered in e88401b. Add the local dependency, preparation and documentation. Update dependency-contract tests while preserving SDK/Flux pins. Verify resolution and missing-checkout diagnostics.

### S2 — App-Level Settings Routing
Description: Delivered in e88401b after S1. Introduce app-level modal composition and replace workspace settings ownership with a callback. Existing implementation retains a temporary Flux/Router synchronization bridge, superseded by S3/S4 below. Verification evidence is in IMPLEMENTATION.md.

### S3 — Explicit Settings Save Outcomes
Description: Extend settings editing/save contracts to identify accepted requests and their outcomes without inferring success from a visibility change, endpoint change or isSaving becoming false (R7/R8). Preserve duplicate-save admission and draft/error behavior. Use focused reducer/middleware tests for successful, unchanged-endpoint, failed and obsolete completions. This preparatory slice may retain the old presentation field until S4; it does not add another visibility flag.

### S4 — Router-Only Settings Presentation
Description: After S3, remove SettingsFeature.isPresented and all production/test references to it. Replace synchronizeSettings and the reverse observer loop with direct Router admission/dismissal and explicit editing lifecycle/outcome handling (R6–R10). Route-scoped settings composition handles Cancel, successful-save dismissal and the saving guard; native dismissal discards edits without mirroring visibility into Flux. Supply modal-derived Stop suppression to WorkspaceContainer and update semantic drivers to use real routing rather than a test-only presentation Boolean. Verify the regression cases in R10, next-connection endpoint semantics, PiUI tests, native iOS settings UI and macOS/iOS Release builds; preserve the macOS automation restriction.

## Open Questions
None.
