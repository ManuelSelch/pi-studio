# Multiline composer implementation status

## Implemented

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
