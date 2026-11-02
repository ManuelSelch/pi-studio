# Working response — revision 1

Status: approved — revision 1. User explicitly approved the mockup in chat.

## Scope
Approximate the existing native transcript in a browser. Show one π label for an entire response, even when text arrives in multiple parts, and a subtle animated “Working…” indicator while the agent is active. No tool-call details are displayed. A subsequent user message begins a new response with its own π.

## States
- `?state=starting`: active before text arrives.
- `?state=working`: active between response fragments.
- `?state=complete`: indicator gone, including a subsequent exchange.

State selector simulates lifecycle; composer is illustrative. Reduced-motion users see a static indicator. Native lifecycle, scrolling, existing message types and actual tool calls are not implemented in this mockup.
