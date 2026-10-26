# Pi Studio / Pi Pocket — Requirements

## Goal
Deliver native macOS **Pi Studio** and iOS **Pi Pocket** with all previously planned native capabilities and functional parity with the current Pi Chat. Share capabilities, not identical layouts; keep Pi Chat usable during migration.

This is the consolidated product backlog. It expands earlier MVP/Pocket exclusions, without rewriting their historical records or authorizing implementation. Detailed sources: [MVP/settings](../../REQUIREMENTS.md), [workspace](../multi-session/REQUIREMENTS.md), [delivery evidence](../multi-session/IMPLEMENTATION.md), [composer](../multiline-composer/REQUIREMENTS.md), and `feat/pocket:docs/pi-pocket/REQUIREMENTS.md`. Pi Chat baseline: local `main` at `4dc0d03`, usage/configuration documentation and current frontend source; native baseline: `f7b8ee6`.

## Requirements

**Priority (proposed):** P0 = safe daily-use foundation; P1 = replacement parity / planned Pocket completion; P2 = convenience / experimental parity. All remain in scope; priority determines order.

**State:** Present = implemented on native main, not necessarily fully accepted; Partial = incomplete behavior or platform coverage; Planned = not implemented; Blocked = acceptance/deployment blocked. States describe the native apps, not Pi Chat. No tests were rerun for this specification. Both platforms apply unless stated otherwise.

### Connection and recovery

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R1 | Explicit connection | Connect/disconnect deliberately; show connecting, connected, ready, stale and failed states; connect creates no session. | P0 | Present |
| R2 | Endpoint settings | Validate/persist ws/wss URLs; Cancel discards edits; Save affects only the next explicit connection. | P0 | Present |
| R3 | Controller handoff | Obtain explicit takeover consent; displaced clients never enter reconnect/takeover loops. | P0 | Present |
| R4 | Safe lifecycle | Mac focus loss keeps networking; window close/iOS background disposes networking, never server work; retain drafts/observed text. | P0 | Present |
| R5 | Foreground recovery | Reconnect/reattach with consent when needed; restore selection or return to browsing if unavailable; never silently create a replacement. | P1 | Planned |
| R6 | Relaunch restoration | Restore ordered open views, selection and drafts scoped to the same server; reconcile missing/replaced sessions safely. | P1 | Planned |
| R7 | Snapshot recovery | Recover transport/sequence gaps through authoritative snapshots, with bounded retry and visible stale state; no mutation replay. | P1 | Planned |
| R8 | Safe failures | Bound requests/buffers; distinguish rejection from unknown outcome; retain uncertain drafts; ignore obsolete callbacks. | P0 | Present |

### Projects and server folders

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R9 | Project catalogue | Browse/search server projects and history; group repositories/worktrees with branch context and live catalogue updates. | P0 | Present |
| R10 | Quick Chats | Keep server home first; create/resume through normal session operations, without a separate chat store. | P0 | Present |
| R11 | Project ordering | Match Pi Chat's pinned/recent/other grouping and unarchived-session recency; no arbitrary recent-project limit. | P1 | Partial |
| R12 | Project pin/removal | Pin/unpin projects; remove eligible inactive entries without deleting folders or transcripts. | P1 | Planned |
| R13 | Server folder picker | Browse/type server directories with breadcrumbs, Up/Home/Refresh, hidden toggle and pagination; Open starts a session there. | P1 | Planned |
| R14 | Folder validation | Resolve relative/tilde/symlink directories server-side; recover from invalid paths and ignore stale replies. | P1 | Planned |

### Sessions and workspace

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R15 | Open/create/attach | Create explicitly; resume saved history or attach running runtimes by server identity without duplicates. | P0 | Present |
| R16 | Desktop workspace | Native Mac split view, compact toolbar and ordered custom tabs; selecting overflowed tabs reveals them. | P0 | Present |
| R17 | Pocket workspace | Native project/conversation navigation and session-overview sheet; no phone tab strip; reuse overview as Mac popover. | P0 | Present |
| R18 | Session switching | Switch while other agents run; observe one live transcript; bind effects/results to their original session. | P0 | Present |
| R19 | Per-session state | Isolate drafts, scroll/follow-tail, admission, errors and unknown outcomes; late results never affect another session. | P0 | Partial |
| R20 | Close view | Close only the local view, discard its draft without confirmation, select a neighbour; last closure leaves browsing connected. | P0 | Present |
| R21 | Runtime identity | Handle server close/replacement without duplicate tabs, wrong drafts or stale transcript adoption. | P0 | Present |
| R22 | Live titles | Reflect authoritative Pi title changes in history, tabs and conversation, including background sessions; no custom rename feature. | P1 | Partial |
| R23 | Archive/restore | Archive idle saved sessions and close their view; browse/restore archived history; never delete transcripts. | P1 | Planned |
| R24 | Quick Switcher | Search projects/sessions and open or focus them through one keyboard-accessible switcher. | P1 | Planned |
| R25 | Session action palette | Discover new/open-folder/archive/close/settings and available server actions alongside Pi commands. | P1 | Planned |

### Conversation and composer

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R26 | Ordered streaming | Render user/assistant messages incrementally without duplicates; authoritative lifecycle determines completion. | P0 | Present |
| R27 | Multiline composition | Preserve exact text; bounded editor growth; Mac Enter sends, Shift+Enter inserts LF; iOS Return inserts LF and icon sends. | P0 | Present |
| R28 | Draft admission | Reject blank/duplicate submissions; clear only admitted matching text; retain rejection/uncertainty and newer edits. | P0 | Present |
| R29 | Native steering | Accept ordinary text while running through Pi's steering queue; show pending/consumed messages and restore queue from snapshots. | P1 | Planned |
| R30 | Stop | Mac Esc/iOS stop icon cancels the targeted work; retain partial output and wait for authoritative settlement. | P0 | Present |
| R31 | Reading position | Follow only at the tail; preserve each open session's reading position when switching. | P0 | Present |
| R32 | Markdown and math | Render GFM, tables, syntax-coloured code and display LaTeX; reject unsafe links/raw active HTML. | P1 | Planned |
| R33 | Thinking and custom messages | Show collapsible thinking, extension custom messages and persistent notices in correct transcript order. | P1 | Planned |
| R34 | Composer focus | Preserve caret/selection/undo/IME; restore focus after dialogs/actions without stealing another editor's focus. | P0 | Partial |

### Tools and files

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R35 | Tool cards | Show grouped/collapsible calls, arguments, progress, results and errors with comfortable/compact presentation. | P1 | Planned |
| R36 | File content rendering | Highlight read/write source; render Markdown previews with remote images disabled; retain literal fallback. | P1 | Planned |
| R37 | Edit diffs | Render line numbers, additions/deletions and syntax colours without losing literal content. | P1 | Planned |
| R38 | File links | Explicit activation opens the file on the server machine through typed operations, never shell/prompt execution. | P1 | Planned |
| R39 | File action safety | Resolve against the originating session; validate paths/types; bound/deduplicate requests and show recoverable errors outside history. | P0 | Planned |
| R40 | Bash results | Show command, output, exit/cancel/truncation and context inclusion; output arrives after completion, not streamed. | P1 | Planned |

### Pi commands and runtime controls

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R41 | Command discovery | Discover/execute Pi extension commands, skills and prompt templates; retain Pi's availability and running-state semantics. | P1 | Planned |
| R42 | Argument completion | Use Pi providers, including async; insert without executing, preserve suffix/caret and discard stale replies. | P1 | Planned |
| R43 | Skill presentation | Display compact expandable skill/source disclosures and separate the user's task from injected instructions. | P1 | Planned |
| R44 | User bash | Support !/!! in the server working directory, context inclusion/exclusion, extension interception and targeted Stop. | P1 | Planned |
| R45 | Model selection | Select available server models; reflect authoritative model/errors; keep provider credentials server-side. | P1 | Planned |
| R46 | Thinking level | Show/change supported thinking levels through server-provided options and guards. | P1 | Planned |
| R47 | Compaction | Invoke native compaction with authoritative progress/errors; preserve Pi's stop-without-resume semantics. | P1 | Planned |
| R48 | Reload | Reload the current runtime's extensions/resources in place; refresh defaults and preserve server identity semantics. | P1 | Planned |
| R49 | Command-driven navigation | Adopt extension-created/switched/forked sessions and resulting identity changes without inventing client-local sessions. | P1 | Planned |
| R50 | Server restart action | Expose advertised restart capability with confirmation/outcome feedback; unavailable hosts show no nonfunctional control. | P2 | Planned |

### Activity and questions

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R51 | Background activity | Show authoritative idle/running/blocked/closing state, including runtimes without open views; reopen without duplication. | P0 | Partial |
| R52 | Unread and attention | Populate/clear unread markers and distinguish unseen output from pending questions; no fabricated timer-based completion. | P1 | Partial |
| R53 | Needs you entry | Quiet red indicators open contextual requests manually; no auto-popup or toolbar running-count summary. | P1 | Planned |
| R54 | Confirm/select answers | Observe and answer typed prompts via SDK; support multiple sessions, stale/withdrawn requests and filtered keyboard selection. | P1 | Planned |
| R55 | Input/editor answers | Complete parity with single-line input, multiline prefill/editing and explicit submit/cancel; unsupported kinds stay visibly disabled until delivered. | P1 | Planned |
| R56 | Later versus cancel | Dismissing attention means Later; explicit Cancel sends cancellation; neither accidentally approves or loses a request. | P0 | Planned |
| R57 | Foreground sounds | Optional persisted chime on completion/attention, without repeated sounds on snapshots or background-push promises. | P2 | Planned |

### Extensions and preferences

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R58 | Extension widgets | Collapsible above/below-composer plain-text widgets with ANSI colour/styles; preserve placement, updates/removal and literal Markdown. | P1 | Planned |
| R59 | Runtime footer | Render server-ordered model/thinking/status labels and badges with native accessible equivalents. | P1 | Planned |
| R60 | Extension actions/slots | Map existing server buttons, badges, actions and extension state to native header/status/composer/settings surfaces; no arbitrary web execution. | P2 | Planned |
| R61 | Appearance | Native light/dark adaptation and legible Markdown/tool/widget palettes; no web-layout dependency. | P1 | Partial |
| R62 | Display preferences | Persist tool density, project-path visibility and hide-archived preference; keep these local and independent of server state. | P2 | Planned |
| R63 | Keyboard behavior | Native shortcut access to switcher/actions; Esc closes the top surface before stopping; preserve copy/selection and IME behavior. | P1 | Partial |
| R64 | Accessibility/layout | VoiceOver labels, non-colour status, Dynamic Type, keyboard navigation, phone targets ≥44pt and keyboard-safe layouts; validate iPad adaptation. | P0 | Partial |

### Security, architecture and acceptance

| ID | Requirement | Short description | Prio | State |
|---|---|---|---|---|
| R65 | Private remote access | Physical Pocket reaches homelab only over VPN and trusted WSS; private backend cannot bypass the chosen access policy. | P0 | Blocked |
| R66 | Client authentication | Resolve remote authorization before deployment; use Keychain for any client secret; no global ATS bypass or client model keys. | P0 | Blocked |
| R67 | Shared native architecture | Native Mac/iOS, shared PiUI, Flux middleware and injected services; pure components; separate Session/Workspace; no Catalyst. | P0 | Present |
| R68 | SDK ownership | Protocol/validation/transport/projections live in standalone PiSDK; extend SDK there, keep one selected transcript and server-owned inventory. | P0 | Present |
| R69 | Reproducible dependencies/CI | Fresh-checkout SDK/Flux preparation and pinned CI inputs; package, iOS unit/UI and native Release jobs with failure artifacts. | P0 | Partial |
| R70 | Isolated regression tests | Semantic drivers and reducer/SDK coverage use owned fixtures, histories, build roots and per-worktree Simulators; repair relocated loopback launcher. | P0 | Partial |
| R71 | Mac interaction acceptance | Verify real keyboard/focus/scroll/accessibility behavior; hosted package tests supplement, not replace, native UI acceptance. | P0 | Blocked |
| R72 | Physical/real-model acceptance | Verify controlled phone VPN use, handoff, steering/questions, recovery and two-turn/Stop flow with real models; clean test-owned resources. | P0 | Planned |
| R73 | Responsive rendering | Keep long history/streaming usable; unchanged historical rich content must not reparse on unrelated token/footer/catalogue updates. | P1 | Partial |
| R74 | Safe diagnostics | Report bounded actionable lifecycle/errors without logging credentials, prompts, model output or tool content by default. | P0 | Partial |

## Assumptions
- This product-level parity plan supersedes earlier exclusions for folder browsing, rich rendering, questions, runtime controls and relaunch restoration; historical feature documents remain supporting records, not competing product backlogs.
- Both apps expose the same supported server capabilities through platform-appropriate UI. Pocket is no longer limited to its earlier minimal-controller scope. iPad polish is not yet accepted.
- One configured server is authoritative for projects, files, history and agents. Single-controller explicit handoff remains intentional; no concurrent-control or cross-server synchronization requirement.
- No new attachments/upload/download system, push notifications, background iOS networking, offline mutation queue, multi-window workspace, custom rename/delete UI, or native repository/worktree-management product is implied by parity. Pi Chat does not currently supply these as general capabilities. Existing extension-owned worktree/verification workflows remain extension-owned.
- Generic extension parity means native presentation of the existing data/actions, not a new plugin framework, terminal emulator, or support for arbitrary custom TUI/web components. OSC widget handling remains deferred, matching current Pi Chat scope.
- Priorities are proposed. Present states are implementation observations from main/evidence, not proof of real-model, physical-device or complete macOS acceptance.

## Implementation Plan

### S1 — Background Activity and Session Isolation
Description: Complete R19/R51/R52 on the existing workspace; verify parallel runtimes, late failures, close/reopen and unread reset without extra live transcripts.

### S2 — Confirm and Select Questions
Description: After S1, deliver R53/R54/R56 through standalone SDK and native UI; verify stale requests, Later/cancel, switching and multiple pending questions.

### S3 — Input and Editor Questions
Description: After S2, deliver R55 with prefill, multiline editing and explicit cancellation; verify keyboard/focus and disconnect behavior.

### S4 — Native Steering
Description: Deliver R29 and running composer behavior using Pi's queue; verify admission, consumption, reconnect snapshots and session-bound Stop.

### S5 — Foreground and Gap Recovery
Description: Deliver R5/R7 over safe lifecycle/error foundations; verify network loss, displaced control, server restart and missing sessions without replay.

### S6 — Relaunch Restoration
Description: After S5, deliver R6 with server-scoped views/selection/drafts; verify relaunch, replacement and unavailable history without automatic creation.

### S7 — Project and Archive Management
Description: Complete R11/R12/R22/R23 and project preferences in R62; verify pinning/order/title updates, archive/restore and no filesystem deletion.

### S8 — Server Folder Selection
Description: Deliver R13/R14 through typed SDK operations and native picker; verify invalid/symlink/relative paths, pagination and stale responses.

### S9 — Rich Transcript
Description: Deliver R32/R33 and R61/R73 rendering foundations; verify math, safe links, ordered notices, thinking and unchanged-history rendering during streaming.

### S10 — Tools and File Actions
Description: After S9, deliver R35–R40 and density preference R62; verify syntax/diffs, failed tools and server-targeted opens without model or shell side effects.

### S11 — Commands, Skills and Bash
Description: Deliver R41–R44/R49 with semantic command/completion drivers; verify insertion versus execution, running semantics, bash Stop and extension navigation.

### S12 — Runtime Controls
Description: Deliver R45–R48/R50 and model/thinking footer values; verify server-advertised availability, compaction/reload semantics and rejected operations.

### S13 — Widgets and Extension Surfaces
Description: Deliver R58–R60 using existing server data/actions; verify ANSI styles, literal Markdown, placements, removal and session isolation; no new extension framework.

### S14 — Navigation and Native Polish
Description: Deliver R24/R25/R57 and complete R34/R61–R64/R73; verify shortcuts, sounds, focus/IME, accessibility, native dark mode and iPhone/iPad sizing.

### S15 — Reproducible Verification and Diagnostics
Description: Complete R69/R70/R74 against current standalone packages; verify fresh-checkout CI configuration, repaired isolated transport acceptance and redacted failures. Preserve native-automation restrictions.

### S16 — Secure Homelab Access
Description: Resolve Q1/Q2 before R65/R66; verify trusted TLS, chosen authorization, invalid credentials/trust and VPN loss without weakening transport policy.

### S17 — Native Replacement Acceptance
Description: After applicable slices, complete R71/R72: authorized Mac interaction checks and controlled physical-phone/real-model parity flows, retaining explicit unsupported cases. Block Mac acceptance on Q3 rather than claiming hosted tests suffice.

## Open Questions
- **Q1** — What VPN hostname and trusted WSS endpoint will Pocket use?
- **Q2** — Will VPN membership alone authorize access, or must the reverse proxy also require an app credential?
- **Q3** — When can native macOS UI automation be authorized again, and can stable runner Accessibility authorization be established?
