# Pi Studio Compact Multi-session Workspace — Requirements

## Goal
Implement the approved revision 4 layout as native SwiftUI on Mac and iPhone: compact project/history navigation, application-managed open sessions, and clear independent agent activity. This document plans implementation only. The user approved the layout with “looks good. Start planning the swiftui layout and components for this”; production implementation is not yet authorized.

Preserve the original MVP/settings plan in the root REQUIREMENTS.md and the Pocket follow-on plan on feat/pocket. This separate feature plan avoids overwriting concurrent middleware-refactor work in the current checkout. Visual reference: [approved mockup](../../mockups/multi-session/DESIGN.md).

## Scope
### In Scope
- Native Mac sidebar, compact toolbar, custom session tabs, conversation and composer.
- Native iPhone project navigation, conversation, session overview and red Needs you entry; no visible tabs.
- Shared project/history/Quick Chats presentation, session identity and per-session local state.
- Open/create/attach flows through PiSDK; independently running server sessions, tab closure without runtime termination, activity and attention presentation.
- Explicit SDK prerequisites for multi-session observation and structured attention; do not treat the browser simulation as implemented capability.
- Reuse endpoint settings, Flux 2 middleware, scoped FactoryKit dependencies and semantic testing drivers.
- Accessible status indicators, platform sizing, keyboard-safe composition and incremental verification.

### Out of Scope
- Finder-style NSWindow tabs, detachable tabs, multiple desktop windows or SwiftUI TabView as the session-tab implementation.
- Full Pi Chat parity, Markdown/tool/thinking rendering, functional model picker, attachment controls, worktree management or project-folder creation.
- Drag-to-reorder tabs, pinning, archive management, cross-device workspace sync and persisted open-tab/draft restoration across launches.
- Automatic reconnect/relaunch recovery, background iOS networking, push notifications, remote authentication and real-model acceptance. These remain separate Pocket/SDK work.
- Numbered keyboard shortcuts in this first layout delivery; keep the ordered selection model ready for a later command-navigation slice.
- Implementation of arbitrary extension dialogs or new permission semantics not supported by Pi Server.

## Requirements
- R1. Follow mockup revision 4. Mac uses a collapsible sidebar around 240 points wide, one compact toolbar, a horizontal custom tab strip, and one selected conversation. Do not constrain the whole window to the old 620-point session width; constrain only the readable transcript/composer region. Native title-bar integration may differ from the HTML chrome; do not draw fake traffic lights or add a second app-title header.
- R2. iPhone displays no session tab strip. Projects occupy the navigation pane and the session overview provides switching/close actions. Returning to projects changes only local navigation. Keep the session title inside the conversation and project context in the compact toolbar. Use available width, native safe areas and at least 44-point touch targets.
- R3. Toolbar summaries: Mac has neither running-count nor Needs you-count summary. iPhone has only the red Needs you badge when needed; no yellow running summary. Session overview remains available on both platforms. Per-session status indicators remain visible in appropriate tabs, rows, overview and conversation.
- R4. Idle is green, running is yellow, Needs you is red. Use semantic colors with light/dark contrast checks and text/accessibility labels so meaning does not depend on color. Disconnected, loading, unavailable, closing and unknown outcomes have explicit neutral/error states; never label unknown state as green idle. Connection status is separate from session execution status.
- R5. Quick Chats is a permanent first entry above Activity and project groups, with a speech-bubble SF Symbol and explicit new-chat action. Its identity/directory comes from the server-designated home project, never a client-local home path or a separate chat store. Preserve project/worktree context and hide archived history by default. Search covers session titles and project context without reordering Quick Chats below projects.
- R6. Use a stable local session key independent of the changing runtime ID. Record server scope, saved sessionPath where available, runtime ID and project path explicitly. Opening the same history/runtime selects the existing local entry rather than creating duplicate tabs. Unsaved runtimes are supported. A failed attach/open never silently creates a new session.
- R7. Keep ordered open-session IDs and the selected ID separately from catalogue/runtime inventory. Per-session local state includes draft, selected transcript scroll anchor, follow-tail preference, unread marker and request/error state. Switching sessions restores these values. A connection attempt and a session-selection attempt have distinct generation guards so late results cannot overwrite the newly selected conversation.
- R8. Closing a tab/session view is a local workspace action: it does not abort, close or archive its runtime and does not disconnect the server. Choose an adjacent open session; if none remains, show a useful empty workspace. Running/blocked sessions without open tabs remain discoverable under Activity/overview. Stop targets only the chosen runtime and waits for authoritative settlement. Confirmed policy: closing a session view discards its nonempty draft without extra confirmation, as decided by the user. Keep this a deliberate action (the close control is per-session and visible), and do not reuse it as a data-loss path for send failures or unknown outcomes.
- R9. Connect requests explicit controller consent and lists projects/runtimes without creating a demo session. New chat is an explicit project/home-directory operation. Connection ownership is workspace-scoped, not tab-scoped; do not create one socket/controller per tab. Saving endpoint settings applies to the next explicit Connect only. All projects and histories belong to the selected server.
- R10. Keep authoritative data in PiSDK and interaction state in Flux. Use a workspace feature for navigation/open ordering/presented surfaces and an ID-keyed session-state owner for drafts/conversations; do not duplicate full transcripts between independent stores. SDK effects belong in Flux 2 middleware, not views or new observable controllers. Continue generation rejection, bounded streams, admitted-versus-completed distinctions, uncertain draft retention and no mutation replay.
- R11 (items a–c delivered in SDK branch `feat/sdk-switching`, `c7ef9a0`; prompts remain for slice 5). Exactly one live transcript at a time, like Pi Chat: the SDK keeps one active session projection, and the app renders one conversation. Do not build a full per-session projection map, per-session gap recovery or multi-session inventory surgery. Before slice 2, verify and minimally extend the Swift client so that: (a) an in-flight mutation or armed run-settlement deadline never blocks selecting another session (keyed, bounded request matching instead of today's single pending slot, which throws on a second concurrent request); (b) Send/Stop are bound to the session they were invoked on, so a late result cannot settle against a later selection; (c) `session.closed`/`session.replaced` for the selected session reach the app as an explicit state instead of silently clearing the projection. Switching sessions must not close or stop server work.
- R12. Background status/unread indicators come from the server's open-session inventory (`session.list.changed`, whose `status` is idle/running/blocked/closing and is republished on runtime status, prompt, closing and removal), never from a timer or a second live transcript. The server already streams every open runtime; the app ignores non-selected sessions' events and re-attaches with `session.snapshot` when selected, which restores the transcript including streamed-so-far assistant text. Preserve the composer draft per session in app state. Auto-scroll only while following the tail, not when the user is reading older content.
- R13. Needs you opens a native popup/sheet with session/project context and a Review request action. iPhone enters from its red badge; Mac enters through a red session indicator or attention row, without adding a toolbar summary. Support multiple pending requests without losing them. Dismissal means Later, not reject/approve. Do not automatically steal focus with repeated popups on catalogue refresh: indicators alone turn red, and the popup opens only when you select that indicator. Ship the `confirm` and `select` prompt kinds first, answered through `prompt.answer`; identify and disable `input`/`editor` rather than simulating a successful answer.
- R14. Keep one app-owned dependency scope and connection lifetime. Mac focus loss does not disconnect; closing the workspace disposes local networking only. iOS backgrounding disposes networking without stopping agents, preserving local drafts and last-known conversation. Show disconnected/stale state on return until explicit reconnect; do not silently imply live data or implement an automatic controller-takeover loop.
- R15. Native settings remain reachable from the connection/footer action. Provide deliberate connection, empty, loading, failure and unknown-outcome surfaces; remove demo-specific large headers and boilerplate without hiding actionable errors. No decorative mockup attachment/model control should ship as an apparently functional button.

### Proposed SwiftUI composition

- Platform App shell → WorkspaceContainer → MacWorkspaceScreen / PhoneWorkspaceScreen. The shell retains window/scene lifecycle responsibility. Screens and components accept plain presentation values and callbacks; only containers import Flux/resolve scoped dependencies.
- MacWorkspaceScreen: NavigationSplitView sidebar/detail with controlled visibility. Sidebar contains WorkspaceSidebar, backed by List/DisclosureGroup-style project sections and search. Detail is a VStack of WorkspaceToolbar, SessionTabStrip and ConversationScreen. Propose a sidebar range of 210–300 points and a default near 240; adapt the final window minimum width to avoid crushing the conversation.
- PhoneWorkspaceScreen: a value-driven NavigationStack with Projects and Conversation destinations; no tab bar. Use standard SwiftUI navigation/presentation state without adopting another router library. Present SessionOverviewScreen as a sheet; it is a popover on Mac. Bridge dismissals back to feature actions so store and native presentation stay consistent.
- WorkspaceSidebar composes QuickChatsRow, ActivitySection, ProjectGroup and HistorySessionRow. Use server/repository/worktree identities rather than flattening every checkout into unrelated projects.
- SessionTabStrip: horizontal ScrollView + LazyHStack of SessionTab components; each has select/close callbacks, label, status and unread presentation. No WindowGroup/NSWindow tab grouping and no fixed-segment TabView. Selecting an overflowed tab scrolls it into view. Mac tab order is the shared open-session order.
- WorkspaceToolbar: platform-specific visible actions from one presentation contract: sidebar/projects, project/branch context, overview, new session, and iPhone-only Needs you. Native toolbar placement must not duplicate the shell's navigation/title rows.
- ConversationContainer bridges the selected keyed session state to ConversationScreen. Reuse/refine SessionTranscript and SessionComposer rather than creating a second chat implementation; replace SessionScreen/SessionHeader's demo composition. ConversationScreen composes SessionContextHeader, inline error/status, transcript and bottom composer. A safeAreaInset or equivalent keyboard-aware arrangement keeps the composer visible.
- SessionStatusIndicator: shared plain enum/presentation mapping to semantic color, shape/text and accessibility label. Used by tabs, rows, overview and status footer. Unread is independent of running/attention.
- SessionOverviewScreen: open sessions plus active sessions without an open view, each with title/project/status; select, close-view and new-session callbacks. Avoid duplicating entries merely because they are both open and running.
- NeedsYouScreen: contextual native sheet/popover with Later/Review; selected request identity lives in Flux state. Actual supported prompt-response UI is gated by PiSDK, not hard-coded into the component.
- ConnectionFooter and WorkspaceEmptyState: reusable plain components for connection/settings actions and empty/loading/failure presentation. Presentation types contain no SDK models or service lookups.
- Keep feature folders vertically organized, e.g. Workspace/{Domain,App,Middleware,UI/Containers,UI/Components}, reusing Projects and Conversation slices where already available. Prefer a small composition container per screen, not one global view with all store bindings. Do not create an abstraction for every visual stack.

### Verification constraints

- Add named reducer and middleware tests per slice, plus independent semantic integration/UI driver workflows: app.projects, app.tabs, app.chat, app.activity and app.attention. Preserve lowerCamelCase vocabulary, bounded waits, source-location forwarding and cleanup on success/failure; fixture controls stay under app.server.
- Use isolated fake server/runtime fixtures, no personal histories or real model credentials. Verify no duplicate opens, concurrent runs, pending admission while switching, closure of the last tab, reopen of a background runtime, isolated drafts, retained partials, stale events and unknown outcomes.
- Validate native visual behavior against revision 4, including toolbar summary visibility, iOS absence of tabs, Quick Chats first, keyboard/safe areas, scroll restoration, VoiceOver and Dynamic Type. Dark-mode adaptation follows system semantics, not hard-coded HTML colors.
- Current root requirements temporarily pause macOS app automation by user request; respect that until explicitly lifted. Package tests, iOS automation and native builds remain allowed. Do not declare Mac UI acceptance complete while its required verification is blocked. Use worktree-specific DerivedData and a dedicated iOS Simulator; never stop another session's tests.

## Assumptions
- Layout approval applies to revision 4, not every simulated backend capability. Popup timing, draft closure and actionable prompt types need the decisions below.
- Open-session ordering, drafts and scroll anchors need only survive navigation within the current app lifetime in this delivery, not relaunch or cross-device transfer.
- Reuse/reconcile the implemented Projects browsing from feat/pocket rather than copying it blindly or replacing it with unrelated client-local catalogues. That branch is not merged into current main; its controller-based session integration must be adapted to the concurrent Flux 2 middleware migration and endpoint-settings flow.
- Proposed SwiftUI primitives/component names are implementation guidance, not an authorization to add platform frameworks, replace the deferred Router choice or refactor unrelated features.

## Implementation Plan

Delivered so far: slices 1 and 2 (see [IMPLEMENTATION.md](./IMPLEMENTATION.md) for evidence and
deliberate limits). Slice 2's SDK prerequisites landed on pi-chat branch `feat/sdk-switching`
(`c7ef9a0`, `3ed2b73`). R7's per-session request/error state and R12's unread population arrive
with slice 4; the iPhone session overview is slice 3.

### 1. Project Browser and Compact Workspace Shell
Description: Reconcile the Pocket browsing feature with the completed main middleware baseline before production edits. Deliver one end-to-end browsing/open/create flow in the shared workspace, with Quick Chats first, compact Mac split-view shell and iPhone navigation, settings access and explicit connection consent. Preserve current plain-text Send/Stop within a single selected conversation while multi-session SDK work is pending; do not advertise independent tabs yet. Verify catalogue updates, no automatic demo creation, project search, history reuse, open failure, endpoint policy and both native builds, with package/integration tests and allowed iOS UI checks. Retain existing shell regression coverage subject to the Mac automation pause.

### 2. Independent Sessions and Mac Tabs
Description: Depends on slice 1. Satisfy R11's narrow switching-safety items first (keyed bounded request matching, selection never blocked by an in-flight mutation or settlement deadline, Send/Stop bound to their session, explicit closed/replaced state for the selected session); no per-session streaming or projection map is required. Then deliver custom Mac tabs backed by ID-keyed local app state and one workspace connection, with duplicate-open prevention, independent drafts, selection, adjacent-tab closure, empty workspace and restored transcript scroll/follow-tail state. Explicitly resolve nonempty-draft closure policy before enabling that action (decided: discard without confirmation). Verify switching while another session runs, switching during a send, targeted effects, retained server-side work, and late selection rejection using isolated SDK/middleware fixtures. Confirm Mac tab layout through allowed build/manual review; no implicit runtime-close operations.

### 3. iPhone Session Overview
Description: Depends on slice 2's shared session model. Deliver open-session switching and close-view actions through an iPhone sheet without rendering a tab strip; reuse the overview as a Mac popover. Include title/project/status, empty state and new-session actions. Verify switching three sessions, isolated drafts, returning to projects without disconnect, closing the last open view, keyboard/safe-area behavior and 44-point controls with semantic integration/iOS UI drivers. No running-count summary is present on iPhone and neither toolbar summary is present on Mac.

### 4. Background Activity and Unread State
Description: Depends on slice 2 and applies to both platform shells (slice 3 for the phone overview). Deliver authoritative green/yellow/red session presentation, running/blocked sessions without open tabs, reopen/attach and unread markers. Closing a running view leaves its runtime observable and running. Verify independent simultaneous status changes, active-session close/reopen, no duplicate overview entries, server removal/closing states, stale connection presentation, local disposal on iOS background/Mac window close and no disconnect on Mac focus loss. Reuse existing lifecycle policy; do not add automatic foreground recovery or timers pretending work completed.

### 5. Needs You Popup
Description: Depends on slices 3–4. Confirmed scope: answer the `confirm` and `select` prompt kinds; `input` and `editor` are shown but disabled. Deliver the contextual native popup/sheet and request selection: red iPhone summary only, Mac attention-row/tab entry, Later versus Review, manual entry from the red indicator and no auto-open, plus multiple-request handling without refresh-triggered modal storms. Remove PiSDK's deliberate prompt rejection and add typed prompt observation plus `prompt.answer` with cancellation for the two shipped kinds; unsupported kinds stay visible and disabled. Verify pending-request identity, stale/withdrawn requests, dismiss/reopen, session switching and authoritative resolution in SDK/middleware fixtures and permitted native UI tests. This slice is incomplete if either shipped prompt kind is only simulated.

## Open Questions

Resolved decisions (user):

- Closing a session view discards its nonempty draft; no retention and no confirmation.
- The first Needs you popup answers the `confirm` and `select` prompt kinds; free-text `input` and `editor` are deferred to a later slice. PiSDK must stop rejecting prompts before this can ship, so slice 5 owns the `prompt.answer` protocol work.
- Needs you is quiet: indicators turn red, and the popup opens only when you select that indicator. No modal opens by itself, including on catalogue refresh.

Remaining open question:

1. None blocking slice 1. The `input`/`editor` answering UI and the eventual recovery/relaunch behavior stay deferred until the confirm/select popup and workspace are in place.
