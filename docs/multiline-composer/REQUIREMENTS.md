# Multiline Composer — Requirements

## Goal
Let users compose multiline messages. On macOS, Enter sends the message and Shift+Enter inserts a new line. On iOS, Enter inserts a new line and the Send button submits the prompt.

## Scope
### In Scope
- Explicit keyboard behavior for the shared native SwiftUI session composer, with macOS delivery first and platform-specific iOS newline behavior.
- Multiline editing, pasting, bounded editor growth, accessibility and existing Send/Stop controls.
- Regression coverage through the existing Flux, integration and native UI test boundaries.

### Out of Scope
- Markdown preview, rich-text editing, attachments, message history navigation or configurable shortcuts.
- Steering, queued messages, sending during generation, draft persistence or new SDK/server behavior.
- Redesigning the conversation screen, settings or connection lifecycle.

## Requirements
- R1. The message input must accept and display multiple lines, including pasted text. Preserve internal newlines, blank lines and indentation when submitting; do not trim the submitted payload. Whitespace-only drafts, including newline-only drafts, remain unsendable.
- R2. On macOS, with the composer focused and sending allowed, an unmodified Enter/Return must invoke the existing send action exactly once, without inserting a newline. Both a single-line and a multiline draft must be sendable this way.
- R3. With the composer focused and editing allowed, Shift+Enter/Return must insert one newline at the caret, replacing any current selection, without sending. Normal caret movement, selection, editing, copy/paste and undo must continue to work.
- R4. On macOS, Enter must use the same eligibility and submission path as the Send button. When sending is unavailable, Enter must neither submit nor modify the draft. Pending admission, generation, stopping, disconnected and connecting states must retain their existing guards; repeated Enter must not create concurrent submissions.
- R5. Preserve admission semantics: clear the submitted draft only after confirmed admission, retain it on rejection or uncertain outcome, and never replay it automatically. Preserve the existing protection against clearing a newer draft. Keyboard handling must not duplicate controller or SDK logic.
- R6. Keyboard interception must be local to the focused composer. Enter used to confirm marked text during input-method composition must not send; users must be able to finish composing text before explicitly submitting. Do not add a window-global shortcut or hijack Enter in settings or other controls.
- R7. Preserve the current compact layout: two visible lines minimum, growth to five visible lines, then internal vertical scrolling with the caret kept visible. Long lines wrap without horizontal scrolling. Keep the Send and Stop controls visible and usable.
- R8. Keep keyboard focus in the composer after an admitted send when editing becomes available again, unless the user has moved focus elsewhere. Shift+Enter and ordinary draft updates must not reset the caret or selection. Preserve the existing Message accessibility label and messageField identifier, plus sendButton and stopButton identifiers.
- R9. On macOS, provide a discoverable, accessible keyboard hint for Enter to send and Shift+Enter for a new line without hiding existing connection/error guidance. On iOS, any input hint must describe Enter as newline and the Send button as submission. Keep native button accessibility and explicit Send available for pointer and touch use.
- R10. Keep the draft in SessionFeature and the controller as the effect owner. SessionComposer remains a value/callback component without Flux, dependency resolution or SDK access. Any platform-specific input adapter must remain scoped to presentation and must not create a second authoritative draft model.
- R11. Verify actual key events in native UI tests, not just direct invocation of the send callback. Cover macOS Enter submission, Shift+Enter at a caret and over a selection, pasted multiline input without automatic sending, whitespace-only input, duplicate Enter during pending admission, and retained multiline drafts after rejection/uncertain outcomes. On iOS, verify Enter inserts a newline without sending and only the Send button submits, for software and hardware keyboards. Verify input-method composition manually if reliable automation is unavailable, recording that limitation.
- R12. Use the existing semantic app.chat test drivers with lowerCamelCase actions and assertions. Keep selectors and platform-specific key-event handling in the UI driver; use integration fixtures to assert the exact submitted multiline payload and admission behavior. Tests must use injected connections or isolated fixtures, never live sessions or model credentials.
- R13. Keep both native macOS and iOS targets building. On iOS, Enter/Return inserts a newline while editing is allowed, for both software and hardware keyboards; Shift+Enter also inserts a newline. Neither key combination sends a prompt. Submit using the Send button with the existing eligibility and admission safeguards.

## Assumptions
- Confirmed: Enter-to-send applies only to macOS. On iOS, Enter inserts a newline and prompts are submitted using the Send button.
- The existing two-to-five-line composer size and current Send/Stop layout should be retained rather than redesigned.
- Existing send eligibility and admission behavior are authoritative and do not require SDK changes.
- Detailed input layout/hint approval, if required by the UI implementation workflow, occurs before production UI changes; this document does not approve a mockup.

## Implementation Plan
### 1. macOS Multiline Keyboard Submission
Description: Deliver the complete macOS interaction through the existing composer, draft callbacks and guarded controller send path. Add focused Enter/Shift+Enter handling, preserve selection and marked-text behavior, retain the two-to-five-line layout and add the shortcut hint. Work test-first with Flux/integration checks for exact multiline payloads and admission outcomes, then native UI scenarios for real key events, selection replacement, pasted content and duplicate-send prevention. Verify focus restoration, scrolling and input-method composition; run PiUI and macOS unit/UI suites and the native Release build. Leave iOS compiling with its current touch behavior; do not change transport, server or unrelated screen behavior.

### 2. iOS Newline Entry and Button Submission
Description: Depends on slice 1. Deliver and verify newline insertion for Enter and Shift+Enter on iOS hardware keyboards and Return on the software keyboard, with submission exclusively through the Send button. Add platform-specific input handling only where needed, behind the same value/callback contract. Extend semantic native UI scenarios for newline entry without submission, Send-button submission of the exact multiline draft, long drafts and accessibility; record any physical-keyboard checks that cannot be automated. Run PiUI, both native unit/UI suites and both Release builds to verify cross-platform regression safety using isolated connections.

## Open Questions
None.
