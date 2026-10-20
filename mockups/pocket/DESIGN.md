# Pocket project and session navigation

- Revision: 2
- Review status: approved for production implementation.
- Goal: choose a small mobile navigation flow for Pocket slice 1.

## Layout and interactions
- Compact single-row toolbar with connection status and explicit Connect/Disconnect. No Pi Pocket title, logo, Development server label or explanatory footer. Session title appears only inside a conversation.
- Reduced header, group, transcript and composer padding; tighter session rows retain 44px minimum touch targets.
- Development endpoint stays fixed at localhost; endpoint settings will be supplied by a later feature.
- Quick Chats is always first, uses a speech-bubble icon and has a New chat (+) action.
- Expand project rows to reveal indented sessions; each project has a New session (+) action.
- Running sessions have a green marker and accessible Running text. Session rows remain regular-weight; linked checkout/branch context is secondary text.
- Tap a session to open its conversation. Projects back button returns to the list without closing/aborting the session.
- New chat/session opens an empty conversation. Connect alone never creates a session.
- Conversation preserves the previous demo's plain-text transcript, composer, Send and Stop. Normal send only while idle; steering and questions belong to later slices.
- Single column at all widths, with a readable maximum width on desktop; no new routing library is implied.
- Browser controls approximate native SwiftUI. Safe areas, Dynamic Type, keyboard and native accessibility behavior require native implementation/testing.

## Review states
- Default: populated, connected catalogue; Quick Chats and pi-studio expanded.
- `?state=empty`: Quick Chats with no history.
- `?state=loading`: awaiting catalogue.
- `?state=error`: catalogue failure with Retry.
- `?state=open-error`: tapping an existing session shows an inline error and stays on the list.
- `?state=disconnected`: explicit connect and takeover confirmation.

## Limitations
All data and responses are fake, in memory only. No server, credentials, persistence, background behavior or real streaming. Opening is immediate; production must guard duplicate/pending opens and use authoritative SDK projections. UI does not imply phone-ready remote connectivity. Exact native desktop presentation will preserve compatibility without introducing a substitute router.

## Approval
Revision 2 approved: user said “approve. implement it”. Implement slice 1 using this compact navigation and fixed localhost endpoint.
