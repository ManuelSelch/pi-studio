# S9 Rich Transcript — Design

## Overview

Implement [product S9](../product/REQUIREMENTS.md#s9--rich-transcript) (R32/R33 and the R61/R73 foundations) using the [approved revision 1 mockup](../../mockups/rich-transcript/DESIGN.md). Extend the standalone Swift SDK to project thinking, custom messages and notices; render those values with native SwiftUI Markdown rather than a WebView.

Copy buttons and clipboard actions are deferred at the user's request. Tool cards, file actions, steering, questions and automatic recovery remain separate slices. The app continues observing exactly one transcript.

## Components

| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| PiSDK | [DemoProjection.swift](https://github.com/ManuelSelch/pi-sdk-swift/blob/f0a1d5c49b2c1e4ba627353689fd8d5946380ec3/Sources/PiSDK/DemoProjection.swift) | Changed | Accumulate text/thinking; reconcile final messages and snapshots; retain typed custom messages and ordered notices in complete projections. No rendering. |
| PiSDK | [PiClient](https://github.com/ManuelSelch/pi-sdk-swift/blob/f0a1d5c49b2c1e4ba627353689fd8d5946380ec3/Sources/PiSDK/PiSDK.swift) | Changed | Own bounded notice retention for this connection and preserve existing sequence, selection and disposal rules. |
| PiUI / Session | [SessionMiddleware](../../Packages/PiUI/Sources/PiUI/Session/Middleware/SessionMiddleware.swift) and proposed `TranscriptRenderModel` | Changed / New | Accept generation-checked projections; prepare ordered, SDK-free presentation values and cached Markdown documents. |
| PiUI / Workspace | [WorkspaceContainer](../../Packages/PiUI/Sources/PiUI/Workspace/WorkspaceContainer.swift) | Changed | Pass prepared values instead of flattening SDK messages to role/text on every render. Existing draft/tab ownership stays unchanged. |
| PiUI / Session UI | [SessionTranscript](../../Packages/PiUI/Sources/PiUI/Session/UI/SessionTranscript.swift), proposed message/thinking/notice components | Changed / New | Render plain values; own disclosure state; forward link callbacks. Compose Markdown blocks without Copy controls. Preserve selection and reading position. |
| PiUI / Session Infra | Proposed Markdown adapter | New | Isolate third-party parsing contracts and URL policy. No clipboard access, networking or server mutations. |
| External package | Proposed [Rill 1.0.0](https://github.com/joydle/rill/tree/v1.0.0) | New dependency | Incremental GFM parser, reusable SwiftUI rendering primitives, syntax highlighting and native math. MIT; no transitive package dependencies. |

SDK state remains authoritative. Flux owns transcript presentation updates, not a second observable interaction store. Parser/cache instances are private, session-observation-scoped implementation details; views receive prepared values. Disclosure state is keyed by runtime plus stable display identity, lives with the conversation view, and is not persisted.

## Runtime flow

1. Pi Server emits existing v2 text/thinking deltas, finalized messages and notifications. PiSDK validates and sequences them before projection.
2. PiSDK accumulates text and thinking in the same active assistant entry. A thinking-only response creates an entry even with empty visible text. Final assistant messages replace that entry, adopt authoritative content and end its partial state. Consecutive assistant messages within one run must not reuse the same display identity.
3. `SessionMiddleware` accepts only the selected runtime/current generation. `TranscriptRenderModel` compares entry identity and source content, parsing only changed Markdown. SDK stream conflation remains safe because every emitted projection is complete.
4. Pure SwiftUI components render assistant Markdown, literal user text, collapsible thinking and distinct custom/notice rows. First-seen live thinking opens expanded; historical thinking starts collapsed. User toggles survive subsequent deltas and finalization. Do not invent thinking summaries or elapsed times.
5. Content growth follows the tail only if the reader was already following. Track content/layout growth, not only the last message ID: the current transcript's ID-only change observer misses streamed updates. Scrolling away preserves the reading anchor; Latest explicitly resumes following. Disclosure, resize and appearance changes must not unexpectedly enable follow-tail.

On Stop or disconnection, retain received text/thinking and display the actual lifecycle state, never a fabricated Complete label. Message finalization alone does not mean the whole run has settled. Obsolete parse results are rejected by generation and content revision, just like obsolete SDK results.

## Contracts & API changes

| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Server v2 → PiSDK | Already supplies `message.thinking.delta`, finalized `thinking`, `customType` and `notification.created`; Swift currently drops most of these | Wire/schema unchanged; no presentation capability negotiation needed. |
| PiSDK → PiUI | `DemoMessage` exposes text/partial state only → structured text/thinking/custom metadata plus typed notice entries and stable display identity | New SDK release required. Update native fixtures/callers together; no legacy mode, wire decoding in PiUI or local-package override. |
| PiUI App → UI | Role/text-only `TranscriptMessage` → ordered typed entries with prepared Markdown documents, lifecycle and disclosure keys | Internal breaking change; migrate all uses/tests. SDK models remain out of Components. |
| Markdown adapter → renderer | No parser → Rill document values with explicit safe render configuration | Pin Rill exactly to 1.0.0 (`7667afee314a655087ae720c879ef4812a84cba9`), with both lockfiles updated during implementation. |

- Keep server message identity separately from display identity so draft finalization does not recreate the row or lose disclosure state. Identify drafts by runtime/run plus a local assistant-message ordinal, not by text prefixes. Snapshots remain authoritative; same-runtime refreshes preserve observed unfinished content, while a newly attached runtime starts from the snapshot. Do not claim the wire contains unobserved partial thinking.
- Notices carry level and literal text. Their identity is server-instance/runtime/sequence. Retain them in a bounded connection-lifetime journal, anchored to adjacent message identities, then merge them into snapshots without duplication. This journal contains notices only, not background transcript projections. Clamp a removed anchor to the nearest surviving neighbour. Event-only notices cannot be reconstructed after reconnect/relaunch; custom messages in snapshots can.
- Apply the existing 4,096-entry/16 MiB transcript bounds to thinking and notices too, including aggregate retained notices. Clear caches/journal on connection disposal. No content-bearing diagnostic logs.

## Decisions & Trade-offs

- **Rill proposal:** source inspection of its 1.0.0 tag confirms growing-snapshot parsing, GFM tables/task lists, highlighted code, native math and no WebView. This avoids writing a Markdown/LaTeX engine. [Textual](https://github.com/gonzalezreal/textual) is a credible alternative with selection support, but would still require a streaming strategy; Foundation `Text` alone does not provide this block-rendering feature set. Rill is a young dependency: native builds and contract tests below are release gates, not checks already passed.
- Use Rill's Foundation-only incremental parser behind the adapter, not its observable `MarkdownSource` as a competing Flux store. Unchanged historical entries never reparse on token, catalogue or footer updates. Coalesce pending render work to the newest projection; do not enqueue a task for every token. Keep caches bounded to the selected transcript. Partial fences/math remain readable and reconcile when completed; unsupported syntax retains literal content.
- Render GFM headings, emphasis, lists/tasks, quotes, tables, links and fenced code, plus display LaTeX. Disable citation extensions and single-dollar math to avoid treating ordinary currency as equations. Code preserves source whitespace; no Copy buttons are added. Tables/code scroll horizontally; long equations must remain accessible without widening the conversation.
- Disable image loading entirely; show alt text. Render HTML literally, never execute it. Reject unsafe/relative/file/custom-scheme link targets in the document adapter and again at activation; only explicit HTTP(S) activation opens the system browser. Table links must obey the same policy. No JavaScript, terminal commands or server-file opens.
- Match the approved density and light/dark appearance using semantic styles. Disable decorative token reveal animations. Rill's block equality ignores theme/config, so invalidate the rendered subtree on appearance/Dynamic Type changes without discarding parsed documents or disclosure state. Add native text selection and accessible math-source descriptions; do not substitute images of prose.
- **Copy is deferred.** Rill 1.0.0 hardwires Copy buttons into its code/table views without a public disable switch. Do not use its complete `DocumentView` unchanged or hide buttons with an overlay. PiUI will compose blocks from the parsed AST: copy-free SwiftUI code/table components and recursive list/quote containers, reusing suitable Rill rendering/highlighting/math primitives. Recursion ensures nested code/tables do not reintroduce Copy. This adds presentation code, not a new parser. Show full code with horizontal scrolling, without a capped preview or separate viewer. No clipboard helper is invoked and no app-owned AppKit API or view wrapper is introduced; RillUI itself still contains an unused platform clipboard helper.

## Verification

Planned checks; no production tests/builds have run for this design:

- **Standalone SDK:** thinking-only/mixed streams; multiple assistant finals in one run; repeated events/snapshots; custom metadata; notice order/retention/bounds; Stop/disconnect retention and selection replacement. Include real protocol fixtures, not only UI stubs. Publish/provision the reviewed SDK release before changing the app's exact pin; do not patch downloaded package sources or publish automatically.
- **Markdown contracts:** compare streamed versus final parsing across Unicode chunk boundaries, incomplete fences/math, nested/task lists and tables. Test raw HTML, unsafe links in every block type, disabled images, unknown languages/math and verbatim code content. Instrument parser counts to prove unchanged historical entries are not reparsed.
- **Native integration/UI:** extend semantic drivers for thinking disclosure, notices, selectable Markdown and reading older output during streaming. Verify same-row growth follow-tail, Latest, interrupted output, theme/Dynamic Type invalidation, narrow tables/code/math, link actions and absence of Copy controls, including nested blocks. Library defaults alone are not acceptance evidence.
- Run PiUI/package and infrastructure checks, dedicated iOS Simulator unit/UI suites and both native Release builds. Native desktop-controlling macOS automation remains paused; use non-activating hosted checks and record remaining manual Mac interaction/selection/scroll acceptance honestly. No real-model acceptance is implied by fixture tests.

## Open Questions

None. The clipboard permission question is resolved by removing Copy from S9; technical-design approval is still required before implementation.
