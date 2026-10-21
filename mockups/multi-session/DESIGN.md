# Compact multi-session workspace

- Revision: 4
- Status: in review; no implementation approval.
- Goal: explore a simpler Mac and iPhone workspace with projects, saved history, multiple open conversations and independent background agents.
- Confirmed direction: application-managed session tabs on Mac, not Finder-style native window tab groups; tabs hidden on iOS. Quick Chats is permanently above Activity and project groups, matching pi-chat.

## Layout

- Mac (`?layout=mac`): approximately 240px collapsible sidebar, single-row toolbar, horizontal session tabs, readable transcript and bottom composer. Projects/history and activity share the sidebar; open sessions are tabs, not duplicated in a separate open-session list. Project history rows may show an Open label.
- iPhone (`?layout=ios`): 393px preview at desktop widths, bounded by available width; compact toolbar without a tab strip; switch open sessions through the overview button. Projects take over the pane. Session overview shows full titles, statuses and close controls. Small-screen targets aim for 44px; compact Mac targets are smaller.
- System typography, light neutral surfaces, green idle, yellow running and red Needs you indicators. A red toolbar badge opens an approval popup; the attention review URL opens it directly. No toolbar summaries on Mac: both the running count and Needs you count are hidden. iOS shows only the red Needs you badge, not a running-count summary. Individual status indicators in tabs, conversations, sidebar and session overview remain unchanged. Connection-green is a separate connection indicator. Browser styling only approximates SwiftUI: native safe areas, keyboard, Dynamic Type, accessibility behavior and system chrome are not validated here.

## Interactions

- Switch tabs, create a session in a project, reopen a saved conversation, search sessions, expand projects, hide the Mac sidebar, open iPhone projects, inspect open/background sessions, close tabs, stop a running agent and approve a request.
- Closing a tab never stops work; running or attention-needed sessions remain in Activity and can reopen as tabs.
- Drafts are isolated per session. Send appends a deterministic mock reply only to the selected conversation. No actual streaming or background execution.
- Cmd/Ctrl+1–9 selects open sessions where not intercepted by the browser. Native command handling is future production work.
- Scroll-position restoration, drag reordering, tab overflow polish, archive actions, persistence, server connections, endpoint settings, actual tools/model controls, recovery and handoff are omitted. Plus/model text inside the composer is decorative.
- All data is in-memory and resets on reload. No credentials, remote assets or APIs.

## Direct review states

Default is populated, with two running sessions (one without an open tab) and one approval-needed session.

- `?layout=mac` / `?layout=ios`
- `?layout=ios&state=overview`: open-session overview
- `?layout=ios&state=projects`: projects navigator
- `?layout=mac&state=attention`: approval-needed conversation with Needs you popup
- `?layout=mac&state=empty`: no open or running sessions, history remains

## Review questions

- Is the Mac sidebar/tab balance compact enough?
- Is the session overview sufficient for switching on iPhone without tabs?
- Should closing a running tab leave the agent running as proposed?

## Approval

Pending user review of revision 4. Production source and app dependencies are untouched.
