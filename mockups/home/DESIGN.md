# Pi Studio Home mockup

- Revision: 4
- Review status: approved.
- Approval evidence: user said “approved. implement it.” for revision 4.
- Goal: replace the disconnected `WorkspaceEmptyState` with a useful Pi Studio landing screen inspired by Pi Chat's home experience.
- Layout: persistent project navigation on desktop, greeting banner, and a quick-switcher input centered vertically. No artwork, Recent conversations section, or footer. Narrow layout hides the sidebar; desktop/phone preview control applies distinct layouts at any viewport width.
- Interactions: quick-switcher accepts text; its Enter behavior is prototype-only. The phone navigation menu represents the existing project navigation. No backend calls or persistence.
- Production behavior scenarios approved separately: connect/take control at launch without creating or attaching a session; on failure remain Home with error and retry/settings; preserve the existing sidebar.
