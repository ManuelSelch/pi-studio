# S9 Rich Transcript — Design

## Overview

Implement [product S9](../product/REQUIREMENTS.md#s9--rich-transcript) (R32/R33 and the R61/R73 foundations) using the [approved revision 1 mockup](../../mockups/rich-transcript/DESIGN.md). Extend the standalone Swift SDK to project thinking, custom messages and notices; render those values with native SwiftUI Markdown rather than a WebView.

Copy buttons and clipboard actions are deferred at the user's request. Tool cards, file actions, steering, questions and automatic recovery remain separate slices. The app continues observing exactly one transcript.

## Components

| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| PiSDK | [DemoProjection.swift](https://github.com/ManuelSelch/pi-sdk-swift/blob/f0a1d5c49b2c1e4ba627353689fd8d5946380ec3/Sources/PiSDK/DemoProjection.swift) | Changed | Accumulate text/thinking; reconcile final messages and snapshots; retain typed custom messages and ordered notices in complete projections. No rendering. |
| PiSDK | [PiClient](https://github.com/ManuelSelch/pi-sdk-swift/blob/f0a1d5c49b2c1e4ba627353689fd8d5946380ec3/Sources/PiSDK/PiSDK.swift) | Changed | Own bounded notice retention for this connection and preserve existing sequence, selection and disposal rules. |
| PiUI / Session | [SessionMiddleware](../../Packages/PiUI/Sources/PiUI/Session/Middleware/SessionMiddleware.swift) and proposed transcript mapping | Changed / New | Accept generation-checked projections; prepare ordered, SDK-free presentation values with source strings and delivery state. |
| PiUI / Workspace | [WorkspaceContainer](../../Packages/PiUI/Sources/PiUI/Workspace/WorkspaceContainer.swift) | Changed | Pass prepared values instead of flattening SDK messages to role/text on every render. Existing draft/tab ownership stays unchanged. |
| PiUI / Session UI | [SessionTranscript](../../Packages/PiUI/Sources/PiUI/Session/UI/SessionTranscript.swift), proposed Markdown container and message/thinking/notice components | Changed / New | Container retains library streaming sources and cached safe parse results per displayed entry; Components render values, own disclosure state and forward links. Preserve selection and reading position. |
| PiUI / Session Infra | Proposed Markdown safety adapter | New | Rewrite parsed HTML/images/unsafe links before rendering; retain source text. No clipboard access, networking or server mutations. |
| External package | [MarkdownView 3.0.0](https://github.com/LiYanan2004/MarkdownView/tree/3.0.0) | New dependency | Incremental/background streaming, SwiftUI block renderer, Highlightr highlighting and SwiftMath math. Use its public code style, not a custom recursive Markdown renderer. |

SDK state remains authoritative. Flux owns interaction state; library parsing state is derived UI-only state, not a second interaction store. The Markdown container owns private streaming sources and safe parse-result caches keyed by runtime/display identity and content revision. Components receive source-derived display values or prepared parse results, never stores/services/SDK models. Disclosure state is keyed by runtime plus stable display identity, lives with the conversation view, and is not persisted.

## Runtime flow

1. Pi Server emits existing v2 text/thinking deltas, finalized messages and notifications. PiSDK validates and sequences them before projection.
2. PiSDK accumulates text and thinking in the same active assistant entry. A thinking-only response creates an entry even with empty visible text. Final assistant messages replace that entry, adopt authoritative content and end its partial state. Consecutive assistant messages within one run must not reuse the same display identity.
3. `SessionMiddleware` accepts only the selected runtime/current generation. The Markdown container updates each retained `StreamingMarkdownSource` only when its source text changes. `StreamingMarkdownReader` coalesces updates and performs incremental/background parsing. SDK stream conflation remains safe because projections and parser inputs are complete snapshots.
4. The safety adapter rewrites a copy of each `MarkdownParseResult.document`, preserving math context, before passing it to `MarkdownView(parseResult)`. Never feed this rewritten tree back into the library's incremental parser. Pure components render assistant Markdown, literal user text, collapsible thinking and distinct custom/notice rows. First-seen live thinking opens expanded; historical thinking starts collapsed. User toggles survive subsequent deltas and finalization. Do not invent thinking summaries or elapsed times.
5. Content growth follows the tail only if the reader was already following. Track content/layout growth, not only the last message ID: the current transcript's ID-only change observer misses streamed updates. Scrolling away preserves the reading anchor; Latest explicitly resumes following. Disclosure, resize and appearance changes must not unexpectedly enable follow-tail.

On Stop or disconnection, retain received text/thinking and display the actual lifecycle state, never a fabricated Complete label. Message finalization alone does not mean the whole run has settled. Obsolete parse results are rejected by generation and content revision, just like obsolete SDK results.

## Contracts & API changes

| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Server v2 → PiSDK | Already supplies `message.thinking.delta`, finalized `thinking`, `customType` and `notification.created`; Swift currently drops most of these | Wire/schema unchanged; no presentation capability negotiation needed. |
| PiSDK → PiUI | `DemoMessage` exposes text/partial state only → structured text/thinking/custom metadata plus typed notice entries and stable display identity | New SDK release required. Update native fixtures/callers together; no legacy mode, wire decoding in PiUI or local-package override. |
| PiUI App → UI | Role/text-only `TranscriptMessage` → ordered typed source entries with lifecycle and disclosure keys; Markdown container owns derived parse results | Internal breaking change; migrate all uses/tests. SDK models remain out of Components. |
| Markdown safety adapter → renderer | No parser → sanitized `MarkdownParseResult` passed through the library's public parsed-result initializer | Pin MarkdownView exactly to 3.0.0 (`6f452b55635246224a3329362e4e11cd3d592a30`); update both lockfiles. Add direct swift-markdown and Highlightr product linkage where the safety adapter/code style imports them, using the versions resolved with MarkdownView. |

- Keep server message identity separately from display identity so draft finalization does not recreate the row or lose disclosure state. Identify drafts by runtime/run plus a local assistant-message ordinal, not by text prefixes. Snapshots remain authoritative; same-runtime refreshes preserve observed unfinished content, while a newly attached runtime starts from the snapshot. Do not claim the wire contains unobserved partial thinking.
- Notices carry level and literal text. Their identity is server-instance/runtime/sequence. Retain them in a bounded connection-lifetime journal, anchored to adjacent message identities, then merge them into snapshots without duplication. This journal contains notices only, not background transcript projections. Clamp a removed anchor to the nearest surviving neighbour. Event-only notices cannot be reconstructed after reconnect/relaunch; custom messages in snapshots can.
- Apply the existing 4,096-entry/16 MiB transcript bounds to thinking and notices too, including aggregate retained notices. Clear caches/journal on connection disposal. No content-bearing diagnostic logs.

## Decisions & Trade-offs

- **MarkdownView selected:** user requested “yes try MarkdownView. implement it” after the [alternatives research](RESEARCH.md). Use its SwiftUI `MarkdownView` path, not the separate RichText-backed `MarkdownText` path. The library supplies parsing, block composition and math; we do not own a recursive Markdown renderer. Native compatibility/performance remain verification gates, not checks already passed.
- Retain one streaming source per response, including its safe parsed result after completion. Start with the library's 50 ms render throttle. Call `finishStreaming()` only when the entry is finalized/interrupted, not on every partial snapshot; create a fresh source for an authoritative edit after finishing. Completed history never reparses on unrelated tokens/catalogue/footer changes. Keep caches bounded to the selected transcript and reject obsolete results by runtime/generation/content revision.
- Render GFM headings, emphasis, lists/tasks, quotes, tables, links and fenced code, plus display LaTeX. Preserve literal code/unknown content. Tables/code scroll horizontally; long equations must remain accessible without widening the conversation. Test currency against the library's math preprocessing; do not promise unsupported parser switches. If its default math recognition cannot meet the required content behavior, revise the design rather than silently replacing the parser.
- **Safety before rendering:** recursively replace HTML blocks with literal code/text, inline HTML with literal text and all image nodes with alt text. Remove unsafe link destinations, preserving labels; allow only absolute HTTP(S) links and recheck on activation. This blocks the library's HTML/SVG WebKit paths, including nested nodes. Register no custom block directives or remote image renderers. Sanitize cached changed documents, not every unchanged row render. No model-generated HTML/JavaScript is executed; Highlightr's bundled highlighting implementation is a separate trusted dependency.
- Match the approved density and semantic light/dark fonts/colors. Theme and Dynamic Type updates invalidate styling/highlighting, not unchanged source parsing or disclosure state. Keep native selection, accessible math-source descriptions and reduced-motion behavior.
- **Copy remains deferred:** install a public `MarkdownCodeBlockStyle` that renders language plus highlighted exact code without Copy or clipboard calls. Reuse library tables/list/quote composition; this style applies to nested code too. Show full code with horizontal scrolling, without a preview cap or separate viewer.
- **Platform boundary:** MarkdownView uses SwiftUI for normal blocks but SwiftMath supplies `NSViewRepresentable`/`UIViewRepresentable` math labels. These library-supplied math wrappers are the only proposed new platform-view boundary; no AppKit editor or app-owned view wrapper is introduced. Approval of this revised design must explicitly cover that boundary. The package also contains WebKit/clipboard code, but our safe rendering path must not invoke it.

## Verification

Planned checks; no production tests/builds have run for this design:

- **Standalone SDK:** thinking-only/mixed streams; multiple assistant finals in one run; repeated events/snapshots; custom metadata; notice order/retention/bounds; Stop/disconnect retention and selection replacement. Include real protocol fixtures, not only UI stubs. Publish/provision the reviewed SDK release before changing the app's exact pin; do not patch downloaded package sources or publish automatically.
- **Markdown contracts:** first verify MarkdownView 3.0.0 builds on both targets and accepts rewritten parse-result documents without losing math context. Compare streamed versus final output across Unicode chunks, incomplete fences/math, nested/task lists and tables. Test literal HTML, zero image loads, unsafe links in every block type, currency, unknown math/languages and exact highlighted code. Instrument source updates/parsing strategies to prove history is not reparsed. No unsafe intermediate document may be rendered while asynchronous filtering is pending.
- **Native integration/UI:** extend semantic drivers for thinking disclosure, notices, selectable Markdown and reading older output during streaming. Verify same-row growth follow-tail, Latest, interrupted output, theme/Dynamic Type invalidation, narrow tables/code/math, link actions and absence of Copy controls, including nested blocks. Library defaults alone are not acceptance evidence.
- Run PiUI/package and infrastructure checks, dedicated iOS Simulator unit/UI suites and both native Release builds. Native desktop-controlling macOS automation remains paused; use non-activating hosted checks and record remaining manual Mac interaction/selection/scroll acceptance honestly. No real-model acceptance is implied by fixture tests.

## Open Questions

None about scope. User selected MarkdownView; approval of this revised technical design, including library-supplied native math wrappers, is required before changing production code or tests. Copy is excluded.
