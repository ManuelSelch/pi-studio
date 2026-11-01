# Native Mac composer and session navigation

- Revision: 6
- Status: revision 6 approved for implementation; revision 4 was the prior layout approval.
- Goal: calmer native-feeling Mac composer, preserve focus after Send, and remove the Mac tab strip and open-sessions toolbar button.
- Mac session switching remains available from the projects/history sidebar. iPhone session overview remains unchanged.
- Quick Chats is permanently above Activity and project groups, matching pi-chat.

## Layout

- Mac (`?layout=mac`): approximately 240px collapsible sidebar, single-row toolbar without an open-sessions button, readable transcript and bottom composer. No tab strip; project/history sidebar rows switch conversations and indicate open sessions.
- iPhone (`?layout=ios`): 393px preview at desktop widths, bounded by available width; compact toolbar without a tab strip; switch open sessions through the overview button. Projects take over the pane. Session overview shows full titles, statuses and close controls. Small-screen targets aim for 44px; compact Mac targets are smaller.
- System typography, light neutral surfaces, green idle, yellow running and red Needs you indicators. A red toolbar badge opens an approval popup; the attention review URL opens it directly. No toolbar summaries on Mac: both the running count and Needs you count are hidden. iOS shows only the red Needs you badge, not a running-count summary. Individual status indicators in tabs, conversations, sidebar and session overview remain unchanged. Connection-green is a separate connection indicator. Browser styling only approximates SwiftUI: native safe areas, keyboard, Dynamic Type, accessibility behavior and system chrome are not validated here.

## Interactions

- On Mac, switch sessions from the projects/history sidebar; on iPhone, use the overview. Create a session in a project, reopen saved history, search sessions, expand projects, hide the Mac sidebar, inspect background sessions, stop a running agent and approve a request. Sending clears the submitted draft and refocuses the composer in this mockup.
- On Mac, switching conversations does not stop work; running or attention-needed sessions remain in Activity and can be reopened from the sidebar.
- Drafts are isolated per session. Send appends a deterministic mock reply only to the selected conversation. No actual streaming or background execution.
- Mac tab strip, open-sessions toolbar button and tab keyboard shortcuts are omitted. Session switching uses the sidebar; iPhone overview behavior is preserved.
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

Revision 6 approved for implementation by the user: “approved. continue.” Approval includes removal of the Mac tab strip, open-sessions toolbar button and Stop button; Mac session switching stays in the project/history sidebar, with Escape to stop. Composer styling is neutral and sending preserves focus. iPhone overview behavior remains unchanged. Browser styling only approximates native controls and cannot establish native focus behavior.
