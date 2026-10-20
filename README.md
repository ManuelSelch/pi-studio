# Pi Studio — first MVP slice

The existing **iPhone/iPad iOS 26.1 target is unchanged**, as requested. This is
connection/demo-session groundwork, not the full chat MVP. The launch screen is
still the Xcode template: no auto-connect, chat UI, streaming, Send or Stop yet.

## Development wiring

- Stable toolchain used: **Xcode 26.1.1 (17B100), Swift 6.2.1**.
- Local SwiftPM product/module: **PiSDK**.
- SDK checkout: `~/.pi/agent/git/pi-chat/packages/pi-sdk`.
- Required SDK commit: **5c9fb4e4971390d8e5949d2a6c1bb10454c5b861**, based on main
  after backend/SDK slices 1–6 (`96ffcb4`). Nothing was published or pushed.
- Xcode has an explicit local package reference relative to this checkout. If
  either repository moves, update that reference; this is not a portable package
  distribution yet.

`DemoConfiguration.development` in [DemoSessionModel.swift](pi-studio/DemoSessionModel.swift)
sets `ws://localhost:8787/ws` and the dedicated **server-side** directory
`/tmp/pi-studio-demo`. Configuration can be injected without a settings screen.
Create that directory on the server before using the real endpoint. The app does
not launch a backend or store credentials. Keep the server loopback-only; no
network bind, broad ATS exception, authentication, or device deployment was added.
Live iOS network acceptance is deferred until there is a connection screen.

## Implemented

- Public SDK actor initializes v2, then creates one demo runtime after admission.
- Explicit `takingControl: true` consent is required: initialization replaces any
  current server controller. Do not connect to a user's active backend casually.
- Connection state, bounded correlated waits, structured rejections and unknown
  create outcomes; no mutation replay or automatic reconnect.
- Injectable URLSession WebSocket transport, shared-contract validation, bounded
  frames and deterministic local disconnect/cancellation.
- Main-actor observable app model injected at the app root. It prevents duplicate
  connects and ignores obsolete callbacks after disconnect. No socket opens on
  app launch; the future screen will call its explicit connect action.

Disconnect does **not** abort or close server sessions. Each later explicit
connection uses a fresh client and creates a new demo runtime. Clean up retained
demo IDs through Pi Chat or explicit v2 `session.close` requests; do not repeatedly
create sessions on a long-lived backend without cleanup. An unknown create
outcome may have left a runtime behind. App/model teardown only disposes local
work, never implicitly closes server runtimes.

## Verification

From this checkout:

```sh
swift test --package-path ../../../../../.pi/agent/git/pi-chat/packages/pi-sdk
xcodebuild -project pi-studio.xcodeproj -scheme pi-studio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test CODE_SIGNING_ALLOWED=NO
```

Passed on this machine:

- SwiftPM's six existing generation-probe tests plus eleven new named tests
  (including four parameterized failure cases).
- Shared valid/malformed contract fixtures and bundled-artifact drift checks.
- Success, denied initialization/create, duplicate-connect prevention, deadlines,
  cancellation, unknown create outcomes, unexpected transport closure, obsolete
  callbacks, malformed frames and unreachable endpoints.
- An actual local Pi Server with a **fake runtime**, empty history, temporary
  metadata and ephemeral loopback port. Exactly one demo is created; disconnect
  retains it; test cleanup explicitly closes it and stops the owned server.
  This test needs the pi-chat checkout's installed Node/tsx dependencies and SDK
  dist (`npm install` / `npm run build:sdk` there). It uses no live conversations,
  model credentials or user server.
- iOS Simulator build, three app-model unit tests and the existing template UI/
  launch tests. Xcode reported TEST SUCCEEDED; a simulator shutdown IPC warning
  appeared after completion, not a test failure.
- `git diff --check` in both repositories.

## Deliberately next

Streaming/session projections and Stop (slice 3), an approved minimal screen
(slice 4), then controlled real-Pi conversation acceptance (slice 5). Dialog
answers, reconnect/recovery, session browsing/opening, public close operations,
optional capabilities and full Swift SDK parity are unsupported. Required
incoming protocol data is validated, but this slice does not project live session
events. Unexpected changes to the ready demo's runtime/question/close state fail
explicitly rather than pretending live support. This does **not** complete the
parent SDK plan's Swift vertical slice.
