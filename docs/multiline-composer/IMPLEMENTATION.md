# Multiline composer implementation status

## Current Mac editor — SwiftUI migration

The approved [SwiftUI migration design](DESIGN.md) replaces the custom AppKit editor with a vertical SwiftUI TextField. This supersedes the AppKit implementation described in the historical record below; workspace-owned per-tab drafts supersede the original local-draft design.

- SwiftUI owns full-width layout/hit testing, two-to-five-line growth, wrapping, focus and selection. No NSViewRepresentable, custom NSTextView, geometry mutation, native event inspection or AppKit editor fallback remains. Existing unrelated native colour styling is unchanged.
- Return delegates to native onSubmit; composer-local SwiftUI key handling distinguishes Shift+Return and suppresses repeated unmodified submission. Shift+Return replaces the selected range with LF, with explicit undo/redo snapshots. Invalid transient selection indices are ignored, not indexed into the draft.
- SessionScreen uses SwiftUI focus/exit commands: pending admission transfers composer focus to the conversation without taking focus from another control; eligible Escape stops, modified/repeated Escape does not. Focus can return when editing becomes available. iOS keeps its prior keyboard-dismissal behavior on Send.
- Red-first reproduction: old editor width48pt versus visible input width724pt. New off-screen semantic driver tests field/editor width and hit targets at 360/760/1708pt host widths, native typing/bindings, external drafts, locks, Return, Shift+Return selection replacement, undo/redo, repeat/whitespace guards, synthetic marked-text submit suppression and Escape across pending admission/running transitions. Hosted editor scenarios serialize their shared native focus machinery.
- Verification: **88 PiUI tests**, three consecutive final-tree passes; both native Release builds; iOS unit suite (normal opt-in transport skip); full **23 iOS UI tests** passed, then the **six iOS multiline scenarios** passed again after the final focus adjustment. No desktop-controlling macOS app automation, live-user server access or real-model acceptance was performed.
- Still manual: real IME candidate preservation/confirmation, physical keyboard behavior, full desktop focus/selection/scroll UX. Artificial marked-text checks establish submit suppression only; they do not prove a real input-method session. In-process local event delivery and off-screen layout checks do not constitute full Mac UI acceptance.
- Project rule: SwiftUI first; ask the user before introducing AppKit.

## Historical implementation

- Composer owns editable text in local SwiftUI state; no session draft action, setter or projection remains. Typing has no callback to Flux. Send passes the exact string snapshot, preserving newlines/indentation/whitespace. Reducer guards readiness, whitespace-only content and duplicate in-flight requests; middleware sends only the admitted action snapshot.
- Reducer emits only an admitted snapshot through `clearDraftMatching`; new submissions reset it, rejection/uncertainty do not emit it, and session-generation guards ignore obsolete results. Composer clears matching text and consumes new instructions. Mounting consumes an old instruction without replaying it.
- Approved mockup revision 2: no keyboard/routine composer hints, no separate macOS Stop button, accessible up-arrow Send icon. Connection status and errors remain visible. Preview stopped; approved sources preserved.
- macOS: narrowly scoped `NSViewRepresentable`/`NSTextView` with native selection, paste, wrapping and local undo. Two-to-five-line measurement with internal scrolling. Text is synchronized only when it differs, not rewritten on every render. Unmodified Return uses the same guarded submit callback as the icon; Shift+Return inserts a native LF at the caret/selection. Submission repeats are consumed. Marked-text commands and unrelated modifiers defer to native handling.
- Esc invokes the guarded stop effect through the editor's command path (including read-only generation). A conversation-level exit-command fallback handles focus elsewhere; settings/alerts, marked text, modifiers, repeats and unavailable cancellation are excluded. No global key monitor or Return shortcut.
- macOS submission retains editor focus across the temporary editing lock; first-responder notifications honor subsequent user focus changes instead of refocusing on streaming renders.
- iOS retains SwiftUI's vertical multiline field, Return/newline behavior and button-only submission. The arrow becomes an accessible stop icon during an eligible run and stays disabled while stopping, with no separate Stop control.

## Verified

- Red: snapshot clear-instruction and keyboard-policy tests initially failed to compile before their contracts existed.
- Green: **42 PiUI tests in 10 suites**, including exact multiline payloads, repeated identical admissions, clear consumption, whitespace/readiness guards, pending-send/stop duplicates, rejection/uncertainty and obsolete results. Keyboard-policy tests exercise normalized values, not native event delivery.
- iOS native unit suite passed (settings integration plus normally skipped opt-in transport test). A later default-device rerun collided with feat-layout automation on the shared iPhone 17 and died before test bootstrap. Both unit and all 19 UI tests subsequently passed on the dedicated `PiStudio-bf5346ecdbbf-Composer` Simulator (UUID `DA271DFA-9ECF-4903-86A7-E8DF1A90A5C0`); it was confirmed Shutdown afterward. No other session was stopped.
- Dedicated reruns used `PI_STUDIO_TEST_DESTINATION='platform=iOS Simulator,id=DA271DFA-9ECF-4903-86A7-E8DF1A90A5C0' bash scripts/test-app.sh ios unit` (then `ui`). Logs are under the worktree-derived build root as `composer-isolated-ios-unit.log` and `composer-isolated-ios-ui.log`. Pipeline status retains the earlier shared-device failure; these equivalent isolated reruns are the final results. Do not run this branch’s default-device suites concurrently with another worktree.
- **19 iOS UI tests passed**: six multiline scenarios, seven chat scenarios, two settings scenarios, four launch/appearance cases. Covers actual software Return tapping, newline event entry without automatic sending, exact multiline payloads, newline-only rejection, long text, matching clear, repeated identical sends, draft retention and touch cancellation.
- Native iOS Simulator and macOS Release builds passed. Native macOS app/unit/UI test products compile with `build-for-testing`, which does not execute tests.
- Fixtures are injected/isolated; no live backend sessions, model credentials or SDK/server changes were used.

## Deliberately deferred verification

- The first macOS UI runner failed before executing tests: LocalAuthentication canceled by user. User then requested “dont run mac automation tests for now”. No macOS native app unit/UI automation or macOS loopback acceptance has been run since that instruction.
- Six macOS interaction scenarios compile but are unexecuted: Return/focus after run, Shift+Return caret/selection/undo, paste/exact payload/Esc, duplicate Return during delayed admission, multiline rejection and uncertain-outcome retention. All go through the semantic `app.chat` driver.
- Manual native checks remain: IME marked-text confirmation/cancellation; actual macOS focus/selection, five-line growth and caret scrolling; Escape behavior in settings/alerts; and physical iOS hardware Return/Shift+Return. XCTest `typeText` newline input is not physical hardware-keyboard proof.
- A different local draft surviving a matching-clear instruction is implemented by direct string comparison but not independently native-UI-verified (editing is locked during admission). No full native acceptance claim is made while the macOS automation pause remains.

## Integration boundary

Reconciled with main's Flux 2 SessionMiddleware. SessionController remains deleted; dependency scopes and lifecycle dispatch remain store/middleware-based. `sendRequested(id, text:)` captures the immutable submitted snapshot in the action; the reducer atomically validates/reserves it and middleware forwards that value rather than reading editable text from state. `clearDraftConsumed` acknowledges successful-admission instructions. Request-ID guards, generation checks, deterministic disposal and weak store ownership are preserved.

The merge initially failed compilation until snapshot actions/clear instructions were reconciled. Integration regressions cover queued snapshot capture, rejection of a later submission before middleware starts, identical submissions, whitespace rejection and pending-send/store-release disposal. Post-reconciliation verification passed: all 42 package tests, iOS native unit tests (one opt-in transport skip), all 19 iOS UI tests, both native Release builds and macOS `build-for-testing` compilation. Native tests ran only on the dedicated Composer Simulator, confirmed Shutdown afterward. Logs: `composer-merge-ios-unit.log`, `composer-merge-ios-ui.log` and `composer-merge-macos-compile.log` under the worktree-derived build root. macOS automation remains paused.
