# Multiline composer
- Revision: 1
- Status: in review; not approved for production UI changes.
- Scope: preserve the existing Message/editor/guidance/Stop/Send layout, adding one subdued accessible shortcut hint between editor and action row.
- macOS: Enter sends; Shift+Enter inserts a newline. iOS: Enter inserts a newline; Send submits.
- Editor: two visible lines minimum, five maximum, wrapping and internal scrolling thereafter.
- Review states: ?platform=mac or ios; ?state=ready, pending or error. Paste/type and simulated sends are local only.
- Browser approximation does not prove AppKit/UIKit caret, undo, IME, accessibility, focus or hardware/software keyboard behavior. These require native verification.
- Existing connection/error guidance remains separate from the keyboard hint.
- Open design question: approve the added hint line in its proposed position?
