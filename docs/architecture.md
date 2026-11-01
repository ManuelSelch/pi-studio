# Architecture

Pi Studio is a native SwiftUI app for macOS and iOS. `PiUI` is a shared Swift package; the platform app targets host the shared feature UI. The app shell owns native window and lifecycle behavior, while PiSDK owns the server protocol and transport.

## Ownership and layers

- **App shell:** [app entry point](../pi-studio/pi_studioApp.swift) owns application lifetime and native windows. iOS backgrounding disposes local networking. On macOS, losing focus does not disconnect; closing the single window disposes the local connection.
- **Features and state:** [SessionFeature](../Packages/PiUI/Sources/PiUI/Session/App/SessionFeature.swift) defines typed actions and app-owned interaction state. FluxStore is the sole observable source of session interaction state. The workspace container owns the composer draft as transient SwiftUI state; switching sessions clears it. Only submitted text snapshots and matching-clear instructions enter the session feature.
- **Effects:** [SessionMiddleware](../Packages/PiUI/Sources/PiUI/Session/Middleware/SessionMiddleware.swift) owns SDK calls, observation tasks, cancellation and disposal. Reducers validate and reserve requests synchronously; middleware submits the exact action snapshot. Request IDs prevent duplicate SDK calls, while generation tokens reject obsolete results. Middleware tasks retain only the weak-backed store handle across SDK suspension. Disconnect joins pending work and streams before settling, without stopping or closing the server runtime.
- **Presentation containers:** [WorkspaceContainer](../Packages/PiUI/Sources/PiUI/Workspace/WorkspaceContainer.swift) maps the server catalogue and local Later membership to plain inbox rows, bridges sidebar actions to workspace middleware, and starts one automatic connection on launch. Retry remains available on Home after a failure. [WorkspaceSidebar](../Packages/PiUI/Sources/PiUI/Workspace/UI/Components/WorkspaceSidebar.swift) presents Needs you, Ready, Running and Later; project/history hierarchy is not part of navigation. macOS uses this sidebar beside Home/conversation; iPhone opens the same sidebar from Home and retains its open-sessions overview. Observable stores use `@InjectedObject`; AppContainer owns settings presentation through Router's app-scoped `ModalRouter`.
- **Components:** [Session UI components](../Packages/PiUI/Sources/PiUI/Session/UI) receive display values and callbacks. They do not access stores, resolve services, depend on SDK models or perform networking. UI-only focus and selection state stays in presentation. The Mac composer is a SwiftUI vertical TextField with selection/focus bindings and keyboard commands; ask before introducing AppKit.
- **Dependencies:** [registrations](../Packages/PiUI/Sources/PiUI/Session/App/SessionDependencies.swift) extend FactoryKit's Container. The app uses the shared container; tests and previews use independent scopes. Registrations include configuration, SDK connection construction and cached main-actor session/settings stores. Each store owns a fresh middleware instance. Install test overrides before resolving cached services or stores.
- **Protocol boundary:** PiSDK owns protocol validation, request correlation, transport, authoritative session projections and run settlement. PiSDK does not depend on Flux or PiUI.

## Data and control flow

1. The view sends a semantic intent through its container, which dispatches a typed feature action.
2. The reducer validates the current state and reserves admitted work synchronously.
3. Middleware performs the asynchronous SDK operation and observes authoritative projections.
4. Middleware dispatches result actions; reducers update feature state, and SwiftUI observes the FluxStore.
5. User drafts remain presentation-local until submission. Submitted snapshots are immutable; matching-clear instructions prevent a later edit from being erased.

## Dependencies

`PiUI` is a local Swift package shared by both platform targets. It imports PiSDK from the local `.dependencies/pi-sdk-swift` checkout so the Swift SDK's `closeSession(sessionId:)` API can be tested directly; `scripts/prepare.sh` links it from `PI_SDK_SWIFT_PATH`. Flux **2.0.1**, Router **2.0.0**, and FactoryKit from **2.5.3** remain resolved packages. See [development and dependency setup](project-guide.md#development-wiring).

## Runtime boundaries

- Workspace launch initiates one connection with control takeover; it does not create or select a session. The app does not start the backend or store model credentials. Retry after failure also takes control directly.
- The catalogue is authoritative for saved history and live runtime status. Session inbox groups derive from server status: blocked → Needs you, idle → Ready, running → Running. Rows show project context first; primary checkouts show the session title, while non-primary worktrees show their branch and add the title when multiple inbox sessions share that checkout. Counts span inbox groups, including Later. Ready includes all unarchived saved idle history, including unopened sessions. Later membership is local UserDefaults intent, scoped to a normalized server endpoint; moving a saved idle session records intent before closing its loaded runtime. Resuming opens its saved path and clears Later membership. Archive remains separate.
- Launch and retry only browse the catalogue; existing runtimes are not attached to, aborted or closed by the app. Disconnect and lifecycle disposal do not imply server-side cancellation or cleanup. Moving to Later is the explicit user action that closes its idle runtime.
- The endpoint defaults to `ws://127.0.0.1:8787/ws`. Debug builds allow local networking; Release does not add an ATS exception. On a physical iPhone, loopback means the phone itself.
- Settings changes apply to the next explicit connection; active connections keep their endpoint snapshot.

For user-visible behavior, development commands, test coverage and known limitations, see the [project guide](project-guide.md).
