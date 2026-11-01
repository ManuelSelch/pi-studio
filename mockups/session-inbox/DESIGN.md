# Pi Studio session inbox mockup

- Status: approved by user and implemented.
- Scope: replace project/history sidebar with session groups matching Pi Chat: Needs you (blocked prompts), Ready (all unarchived idle saved sessions), Running (working sessions), Later (explicitly parked idle saved sessions).
- Sidebar omits project browsing/history hierarchy. Project and branch remain secondary row context.
- Ready rows can be moved to Later with the pause-clock action; Later rows can be resumed. The mockup demonstrates the interaction only; production persists Later locally per endpoint and closes/reopens runtimes through PiSDK.
- Empty status groups and empty Later shelf are hidden. Running and Later groups are collapsible. Needs you rows are visibly distinct.
- Browser layout approximates the Mac workspace; it does not validate native accessibility, keyboard focus, or iPhone presentation.
- The user reviewed and approved the preview, including the Later move/resume interaction, blocked prompt, and Running sessions.
