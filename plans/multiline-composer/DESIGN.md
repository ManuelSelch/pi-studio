# SwiftUI Mac Composer — Design

## Overview
Replace the AppKit-backed `MacMessageEditor` with a SwiftUI multiline `TextField`, preserving the approved composer layout and keyboard behavior. This addresses the reproduced hit-testing bug: SwiftUI measurement leaves a 34pt native editor inside a 728pt scroll view.

Use the existing [composer requirements](REQUIREMENTS.md) and [product requirements R27/R28/R34](../product/REQUIREMENTS.md). The user's new SwiftUI-first direction supersedes the earlier recommendation to use NSTextView; ask before introducing AppKit. No new mockup is proposed because this is an implementation replacement, not a layout redesign.

## Components
| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| PiUI / Session UI | [MacMessageEditor](../../Packages/PiUI/Sources/PiUI/Session/UI/MacMessageEditor.swift) | Changed | SwiftUI field, selection, focus and local keyboard handling; remove coordinator/native sizing |
| PiUI / Session UI | [SessionComposer](../../Packages/PiUI/Sources/PiUI/Session/UI/SessionComposer.swift) | Reused | Draft binding, content validation and Send/Stop callbacks |
| PiUI / Session UI | [SessionScreen](../../Packages/PiUI/Sources/PiUI/Session/UI/SessionScreen.swift) | Changed | Preserve focus/Escape behavior using SwiftUI rather than AppKit event inspection |
| PiUI / Session UI | [MacComposerCommand](../../Packages/PiUI/Sources/PiUI/Session/UI/MacComposerCommand.swift) | Changed as needed | Retain only command policy actually used by the SwiftUI implementation |
| PiUI / Workspace | WorkspaceContainer and store | Reused | Own per-tab drafts and admission-driven matching clears; no state-ownership migration |

## Runtime flow
1. SessionComposer supplies the selected draft binding and readiness to MacMessageEditor.
2. SwiftUI lays out the vertical TextField with two-to-five lines, wrapping and internal scrolling; focus/selection remain presentation state.
3. Native field submission invokes the same guarded Send callback as the button. Composer-local SwiftUI key handling implements Shift+Return insertion at the selection, not appending to the end.
4. Existing middleware handles admission; only a matching admitted draft clears. Rejection/uncertainty retains text.
5. Escape invokes eligible Stop without hijacking settings/dialogs or input-method cancellation. Readiness locks and iOS behavior remain unchanged.

## Contracts & API changes
| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| SessionComposer → MacMessageEditor | Binding/readiness/focus/callbacks → same inputs | Internal contract unchanged |
| Mac editor → SwiftUI | NSViewRepresentable and manual geometry → SwiftUI View | Implementation replacement, no native-view compatibility shim |
| Workspace/Session → SDK | Existing draft/admission/send/stop flow | Unchanged; no package or wire changes |

## Decisions & Trade-offs
- Use SwiftUI TextField, FocusState and selection APIs; no introspection library, AppKit event monitor or hidden window-global Return button.
- Prefer native onSubmit for Return/IME handling. Preserve Shift+Return with selection-aware SwiftUI handling; never simulate newline by replacing the entire draft after submission.
- Native macOS TextField commonly uses Option+Return for newline; Shift+Return and IME interactions must be verified, not assumed equivalent. If the required behavior cannot be preserved safely in pure SwiftUI, stop and ask rather than adding AppKit or silently changing shortcuts.
- Keep existing unrelated AppKit colour styling outside this migration; no new AppKit usage. Do not retain AppKit keyboard inspection as a backdoor in SessionScreen.

## Verification
- Replace tests coupled to the custom NSTextView with behavioral coverage; retain draft/admission/session-switch regressions.
- Off-screen package checks must exercise layout/hit targets across the field, not merely set its text programmatically. Test narrow/wide layout, retained drafts and locks without activating windows.
- Run package tests and both native builds; use isolated iPhone/iPad Simulator regression tests where relevant.
- macOS desktop-controlling automation remains paused. Explicitly record pending manual Mac checks: full-width clicking, Return/Shift+Return, selection/undo, repeat prevention, IME, Escape and focus after send. Do not claim Simulator checks prove Mac keyboard acceptance.

## Open Questions
None. Design approval is required before production or test changes.
