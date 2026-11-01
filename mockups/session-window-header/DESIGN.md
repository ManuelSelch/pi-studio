# Session window header

- Revision 1: approved.
- Goal: remove the standalone session header and place project › session title, session actions and status in the native macOS window titlebar instead of the Pi Studio title. Window controls remain on the left.
- Remove the composer Message label; retain the accessible message field. Add space between the titlebar divider and transcript content, including errors.
- Review the normal state and ?state=error. Session selection and titlebar actions are local simulations; close leaves the simulated session in the sidebar.
- Browser-rendered window chrome approximates SwiftUI/macOS behavior; it does not establish native toolbar layout or draggable areas. No backend is connected.
- Preserve the existing approved revision in mockups/session-title; no change to existing journeys is implied by this visual design.
- Approval: user approved revision 1 for implementation.
