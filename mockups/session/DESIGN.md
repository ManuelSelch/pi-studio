# Minimal demo session screen

- Revision: 1
- Review status: approved.
- Approval evidence: user said “mockup looks good. implement it” for revision 1.
- Goal: expose the existing connection/demo state and add the smallest useful plain-text streaming conversation UI, retaining the iOS Simulator target.

## Layout and behavior

One native SwiftUI screen: title, Demo session label, connection state and Connect/Disconnect, small endpoint/directory caption, inline error, scrolling plain-text transcript with role labels, message field, Send and Stop. Neutral system styling, no custom chat bubbles, Markdown, navigation or settings.

Narrow screens use available width; wider screens keep a readable single column. SwiftUI will handle native safe areas, keyboard and Dynamic Type; the browser layout only approximates these.

Connect requires explicit takeover consent and creates one fresh demo runtime. Connecting is distinct from ready. Send is enabled only while idle with nonempty input, with duplicate submissions disabled while admission is pending. Clear the submitted draft only after admission; retain it on rejection or uncertain outcome. Receive text incrementally, without duplicate finalized text. Keep the partial answer after Stop and display Stopping until authoritative settlement. Ready allows another turn.

Disconnect during generation warns that server work may continue. Disconnect does not close server runtimes. Keep the transcript visible on disconnect/failure; reset it only for another explicit connection. Errors and unknown outcomes remain visible. Structured questions will be explicitly unsupported rather than reported as normal completion.

## Review states

`?state=disconnected` (default), `connecting`, `ready`, `generating`, `stopping`, `error`, `unknown`. The selector beneath the app is mockup-only, not production UI. Click Connect and confirm; type a message and Send to simulate incremental text; Stop simulates cancellation settlement. All responses/admission/timing are fake. No backend calls, credentials or persistence.

## Approval

Revision 1 approved for native SwiftUI implementation and SDK streaming/Stop. Preserve this mockup as the design reference. Native keyboard, safe-area and system control appearance will follow SwiftUI rather than browser styling.
