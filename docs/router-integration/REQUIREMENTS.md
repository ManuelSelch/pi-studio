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
- **R7** — SettingsFeature owns editing and persistence state only: saved endpoint, draft, validation/error and saving progress. Beginning a new settings flow resets its draft/error; duplicate open requests preserve the current flow and edits. Cancel and interactive dismissal discard unsaved edits without persisting them. Neither can dismiss while saving. Do not add a success-status field solely to trigger navigation from a view observer.
- **R8** — Middleware directly dismisses the originating settings flow after successful persistence, including when the endpoint is unchanged; failures retain the draft and error in the open flow. Admit at most one save at a time; block editing, repeat Save and dismissal while saving. Duplicate or obsolete work must not dismiss a newer flow or overwrite newer edits. Remove UUID save-request bookkeeping from Flux actions/state; retain any necessary presentation-identity safety inside middleware/Router, not in action payloads.
- **R9** — Workspace Stop suppression derives from actual modal presentation supplied by app-level composition, not settings business state. Workspace must not inspect SettingsFeature to determine visibility. Preserve the existing pure screen callback/value boundary.
- **R10** — Update reducer, middleware, app-routing and semantic integration drivers to assert editing outcomes separately from Router presentation. Cover cancellation/reopening, duplicate opens, saving guards, failed saves, unchanged-endpoint success, obsolete completion and active-session preservation; verify native iOS dismissal wiring and both platform builds.
- **R11** — Inject the same app-scoped ModalRouter into settings middleware and the app-level host. Middleware owns navigation side effects for Open, Cancel and successful Save, including the saving dismissal guard. AppContainer renders the router without observing Flux save outcomes to trigger navigation. Native dismissal only signals editing cleanup; it must not recreate two-way visibility synchronization. Tests own isolated router/store scopes.

## Assumptions
- First integration covers settings only; session overview surfaces and phone navigation remain unchanged.
- Use an ignored .dependencies/router link with a PI_ROUTER_PATH override so worktrees need not share the original folder layout.

## Implementation Plan
### S1 — Local Router Dependency
Description: Delivered in e88401b. Add the local dependency, preparation and documentation. Update dependency-contract tests while preserving SDK/Flux pins. Verify resolution and missing-checkout diagnostics.

### S2 — App-Level Settings Routing
Description: Delivered in e88401b after S1. Introduce app-level modal composition and replace workspace settings ownership with a callback. Existing implementation retains a temporary Flux/Router synchronization bridge, superseded by S3/S4 below. Verification evidence is in IMPLEMENTATION.md.

### S3 — Middleware-Owned Settings Navigation
Description: Replace the previous explicit-save-outcome proposal with direct navigation side effects (R6–R9/R11). Inject one app-scoped ModalRouter into SettingsMiddleware and AppContainer. Middleware presents on Open, dismisses on Cancel or successful persistence, and manages the saving guard; failures leave settings open. Remove SettingsFeature.isPresented, UUID save-request bookkeeping and synchronizeSettings, without introducing navigation-triggering success state or view observers. Keep Flux actions focused on user intent and editing/persistence results. Wire native dismissal to draft cleanup only, supply modal-derived Stop suppression to WorkspaceContainer, and update affected drivers/tests to use the real router. Verify focused reducer/middleware tests for duplicate admission, failure/retry, unchanged-endpoint success, guarded dismissal and presentation-identity safety.

### S4 — Settings Routing Regression Verification
Description: After S3, complete R10 through semantic integration and native iOS UI scenarios covering Cancel, swipe-dismiss/reopen, duplicate opens, successful/failed saves and active-session preservation. Verify next-connection endpoint semantics, isolated dependency scopes, no remaining settings visibility flag/synchronization loop or UUID save-action bookkeeping, PiUI tests and macOS/iOS Release builds. Preserve the macOS automation restriction. S3 owns the production routing change; S4 validates it rather than introducing another presentation mechanism.

## Open Questions
None.
