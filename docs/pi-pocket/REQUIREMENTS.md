# Pi Pocket — Requirements

## Goal
Provide a small native iPhone app for browsing projects and sessions, using Quick Chats, and steering agents hosted by Pi Server on the homelab over VPN. Build on the existing shared PiUI demo rather than replacing its architecture. The root REQUIREMENTS.md remains the historical MVP plan; this document defines the Pocket follow-on.

## Scope
### In Scope
- Server connection configuration and explicit single-controller handoff.
- Project/session browsing, opening existing sessions and starting sessions in existing projects.
- Quick Chats creation and resumption.
- Streaming conversations, native steering, Stop and structured question responses.
- Foreground reconnection and secure access to the homelab over VPN.

### Out of Scope
- Concurrent desktop/phone control, multiple servers and synchronizing independent server installations.
- Full Pi Chat parity, project-folder browsing, worktree management UI and rich tool/attachment presentation.
- Push notifications, background networking, offline mutations and App Store distribution.
- Server/SDK repository extraction or publication.

## Requirements
- R1. Use PiSDK for protocol, transport and authoritative projections. Extend the Swift SDK in its own workspace; keep PiUI's Flux, FactoryKit and container/component separation. Preserve native macOS builds and defer the selected Router library until it supports macOS.
- R2. Connecting must not create a demo session. Show the server's projects and saved sessions, distinguish running sessions, and open or attach using server identities without duplicating an existing runtime. Project and session selection remain app-owned.
- R3. Present the server-designated Quick Chats project first. New chat creates a session in the server's home directory; existing chats use the same session-opening flow as project sessions. Do not introduce a separate chat store.
- R4. Allow sending while idle and native Pi steering while running. Show queued steering and authoritative run state. Stop preserves partial output and waits for settlement. Support structured questions through the existing protocol, including cancellation and stale-response rejection.
- R5. Backgrounding disconnects local networking without aborting or closing server work. Preserve selected history/runtime identity and per-session drafts. On foreground or relaunch, reconnect with explicit takeover consent where required and restore the selection if still available; otherwise return to browsing. Server restarts and missing sessions must be recoverable without silently creating sessions.
- R6. Never replay mutations automatically. Preserve uncertain drafts, visibly distinguish unknown outcomes, and refresh authoritative state before further action. Displaced controllers must not enter a reconnect/takeover loop.
- R7. Support a configurable server URL. For homelab acceptance, restrict reachability to the VPN and use trusted HTTPS/WSS through a reverse proxy, keeping Pi Server private. Define authentication before remote deployment; store any client secret in Keychain. Model/provider credentials stay on the server. Do not add global transport-security exceptions.
- R8. Approve a small mobile navigation mockup before production UI changes. Verify each slice with SDK/app tests and semantic integration/UI drivers using isolated fixtures. Run macOS regression checks for shared changes. Final acceptance uses a physical phone over VPN and explicitly authorized, isolated real-model sessions; clean up test-owned resources.

## Assumptions
- The homelab is the authoritative host for projects, histories and agent runtimes. Desktop Pi Chat connects to that same server when handoff is needed; independent Mac sessions are not automatically available.
- The existing server catalogue and v2 operations can support these flows; Swift SDK coverage must be expanded.
- VPN connectivity, server-side project folders and model configuration are provisioned separately. The exact deployment/authentication configuration is unresolved below.

## Implementation Plan
### 1. Projects, Sessions and Quick Chats
Description: Approve a minimal mobile browsing/navigation mockup, then extend the Swift SDK and shared UI to show the catalogue, attach/open existing sessions and start new project sessions or Quick Chats. Remove automatic demo creation from the product connection flow. Verify cold catalogue updates, running/history attachment, duplicate-open prevention, Quick Chats and failed opens with isolated SDK and UI fixtures. Keep this slice on the development server.

### 2. Foreground Recovery
Description: Depends on slice 1. Retain selection and drafts, dispose networking on background, and reconnect/reattach on foreground or relaunch without replaying mutations. Verify active work continues on the server, controller handoff, server restart, missing history and unknown request outcomes. Do not add background execution.

### 3. Steering and Questions
Description: Depends on slice 2. Add native steering during active runs, queued-message presentation and structured question responses alongside existing streaming and Stop. Verify admission versus completion, consumed steering, cancellation, stale questions and connection loss during interaction using isolated fixtures and semantic drivers.

### 4. Homelab and Phone Acceptance
Description: Depends on slices 1–3. Resolve the URL/TLS/authentication choices, add connection settings and any required Keychain-backed credentials, and document the VPN-only reverse-proxy/server setup. On a physical phone, verify browsing, Quick Chats, steering, questions, foreground recovery and explicit desktop handoff. Exercise VPN loss and invalid credentials/trust without bypassing security. Complete a controlled real-model acceptance flow and clean up test resources; do not imply earlier demo tests already prove this.

## Open Questions
1. What VPN hostname and trusted HTTPS/WSS endpoint will Pocket use?
2. Should VPN membership alone authorize access, or should the reverse proxy also require an app credential?
