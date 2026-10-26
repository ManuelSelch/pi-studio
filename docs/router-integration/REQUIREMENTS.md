# Router Integration — Requirements

## Goal
Use the modernized local Router in Pi Studio/Pocket and move settings presentation out of the workspace without changing the interface.

## Requirements
- **R1** — PiUI consumes the Router library from the existing local router-modernized checkout. Do not publish or copy library sources.
- **R2** — An app-level container hosts settings with ModalRouter/ModalRouterView on macOS and iOS. Workspace requests settings through a callback.
- **R3** — Preserve draft reset, validation, persistence, Cancel, successful-save dismissal, interactive dismissal and the saving dismissal guard. Failed saves remain visible; saved endpoints apply only to the next explicit connection.
- **R4** — Preserve session selection, tabs, drafts, transcript, connection lifecycle and Stop suppression while settings is visible. Do not replace session tabs with TabRouter or introduce unused stacks.
- **R5** — Preserve existing SDK/Flux release pins. Document local Router preparation and fail clearly if unavailable. Keep external build roots and the macOS automation restriction.

## Assumptions
- First integration covers settings only; session overview surfaces and phone navigation remain unchanged.
- Use an ignored .dependencies/router link with a PI_ROUTER_PATH override so worktrees need not share the original folder layout.

## Implementation Plan
### S1 — Local Router Dependency
Description: Add the local dependency, preparation and documentation. Update dependency-contract tests while preserving SDK/Flux pins. Verify resolution and missing-checkout diagnostics.

### S2 — App-Level Settings Routing
Description: After S1, introduce app-level modal composition and replace workspace settings ownership with a callback. Verify settings/connection behavior, package tests, iOS settings UI and native builds; no macOS UI automation.

## Open Questions
None.
