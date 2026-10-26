# Pocket slice 1 — Implementation record

## Reconciliation with current main

This is historical evidence for the original controller-based Pocket slice, not
current architecture or a fresh verification claim. During merge reconciliation,
main's WorkspaceFeature/WorkspaceMiddleware and separate SessionFeature were
retained: they already implement catalogue browsing, Quick Chats, explicit
create/open/attach, local navigation and per-session drafts. Workspace integration
and browsing UI tests supersede the original Pocket controller tests/drivers.
Main's endpoint settings, phone session overview, SwiftUI composer, released
PiSDK/Flux dependencies and per-worktree Simulator isolation are preserved.
The approved Pocket mockup remains a historical reference; the newer workspace
layout remains authoritative. No obsolete controllers or duplicate screens were
restored. Current scope is tracked in [product requirements](../product/REQUIREMENTS.md);
the delivery and test results below describe the original branch only.

## Delivered

- Approved compact mockup revision 2; preview stopped and reference preserved.
- Localhost-only browsing, no endpoint settings and no automatic demo creation.
- Quick Chats first; repository/worktree grouping, saved history, unsaved/running
  runtimes, explicit creation, attach/open, local back navigation and isolated drafts.
- Reused plain-text conversation, idle Send, streaming and Stop with bounded
  admission/settlement, unknown-outcome handling and generation guards.
- New Swift SDK APIs live in a separate pi-chat worktree/branch, not in PiUI.

## Dependencies and commits

- App branch: `feat/pocket`; feature `af0bfe7`, Simulator isolation `0a95ac2`.
- SDK commits `3e4612d`, `3abb883` were merged into pi-chat **main** as
  `9f8e5b8`. Pocket now uses the default main SDK checkout via
  `bash scripts/prepare.sh`; the feature-worktree override is no longer needed.
- The app branch remains unmerged. Nothing was pushed or published.
- After switching to main, all 28 SDK tests, all 24 PiUI package tests and both
  native Release builds passed again.

## Verification

- All seven configured suites passed together: package tests, iOS/macOS unit/UI
  tests and both Release builds.
- Swift SDK: 28 named tests passed, including real loopback Pi Server with a fake
  runtime, cold Quick Chats catalogue, explicit creation, streaming, retained-runtime
  reattachment and explicit cleanup.
- PiUI: 24 named package tests, including project grouping, history/runtime
  identity, cold catalogue updates, failed/unknown opens, duplicate selection,
  stale callbacks and draft isolation. Nine project tests also run natively.
- iOS UI: 12 executions; macOS UI: 10. Both include eight functional workflows
  plus launch/appearance tests. Native projects/saved-chat screenshots are attached
  to the UI results and were inspected against the compact approved layout.
- Four script-level Simulator-isolation tests passed.
- Explicit native SessionController/Flux/URLSession fake-runtime acceptance passed
  on iOS and macOS, with one retained runtime explicitly closed during each cleanup.
- No live user session, model credentials or real-model acceptance was used.

## Test collision diagnosis

An initial parallel iPhone 17 run collided with the settings worktree's installed
app/test runner. The crash report named a DYLD missing settings symbol and was an
iOS Simulator process, not proof of macOS incompatibility. Tests passed on a
separate device. Scripts now select/create a per-worktree Simulator by UUID, with
an explicit destination override still available. No unrelated tests/processes
were stopped and no OS update was performed.

## Remaining work

Foreground/relaunch recovery is slice 2; steering and structured questions are
slice 3. Homelab/VPN and physical-phone real-model acceptance remain deferred.
The separately developed settings feature must be integrated explicitly later;
Pocket currently reads the fixed SessionConfiguration endpoint. Swift runtime-close
UI, Markdown/tool/thinking rendering and full Pi Chat parity remain unsupported.
