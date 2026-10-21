# Multiline composer implementation status

## Slice 1 — implemented, macOS UI verification deferred

- Composer owns editable text in local SwiftUI state; no session draft action, setter or projection remains.
- Send passes the exact string snapshot. The controller guards readiness, whitespace-only content and duplicate in-flight requests.
- Reducer emits an admitted snapshot through `clearDraftMatching`; new submissions reset it, rejection/uncertainty do not emit it, and session-generation guards ignore obsolete results.
- Composer handles only changed instructions, clears matching text and consumes the instruction; mounting consumes any old instruction without replaying it.
- Existing layout and keyboard behavior are unchanged. Keyboard handling/hints and iOS-specific newline acceptance remain slices 2–3.

## Verification

- Red: new Flux clear-instruction tests failed to compile before implementing the contract.
- Green: 29 PiUI package tests, both native unit suites, 13 iOS UI tests (including launch/appearance coverage), and both native Release builds passed.
- macOS UI runner failed before executing tests: LocalAuthentication canceled by user. User then requested: “dont run mac automation tests for now”. Do not rerun macOS automation until authorized.
- All tests use injected connections; no live model/session tests were run.
- Remaining: macOS native UI verification; UI-local differing-draft/caret and multiline native interaction coverage in subsequent slices; IME/manual hardware-keyboard verification.
