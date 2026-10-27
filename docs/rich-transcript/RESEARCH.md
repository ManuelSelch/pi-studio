# Markdown renderer alternatives for S9

## Recommendation

**Evaluate LiYanan2004/MarkdownView 3.0.0 first, with Textual 0.5.0 as the alternative.** MarkdownView combines an explicit incremental/background streaming pipeline with an extensible SwiftUI renderer. Unlike Rill, it offers a public code-block style protocol, so removing Copy does not require replacing recursive block rendering.

This is a source/documentation assessment, **not a build, performance benchmark or adoption decision**. The existing DESIGN.md still proposes Rill; changing that choice requires revising and approving the design. No application dependency was changed.

## Comparison

All candidates support native macOS and iOS; all minimum OS versions are below Pi Studio's targets.

| Library | Streaming | Tables / code highlighting / math | Copy-free presentation | Main trade-off for Pi Studio |
|---|---|---|---|---|
| [MarkdownView](https://github.com/LiYanan2004/MarkdownView), 3.0.0 | Dedicated source/reader; coalesced, incremental and background processing; final full parse | Yes / Highlightr / SwiftMath | Public `MarkdownCodeBlockStyle` can replace the default Copy-bearing code style | Math uses platform view wrappers; HTML/SVG can use WebKit and must be excluded; larger dependency graph |
| [Textual](https://github.com/gonzalezreal/textual), 0.5.0 | Accepts changing text, but no dedicated incremental streaming pipeline found | Yes / bundled Prism / SwiftUIMath | Default and GitHub code styles have no Copy button; custom block styles supported | Changed source triggers parsing of that markup; need to validate long active-response performance and incomplete syntax |
| [SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown), v0.7.0 | Dedicated streamed snapshots, incremental rendering | Yes / HighlightSwift / iosMath | Code view contains hardwired Copy; inspected config has no hide-Copy flag | More platform-backed rendering than its SwiftUI-facing API suggests; Copy problem remains |
| [MarkdownExtendedView](https://github.com/ChrisGVE/MarkdownExtendedView), 1.2.4 | No dedicated streaming API documented; inspected main parses in `body` | Yes / built-in highlighter / ExtendedSwiftMath | Inspected renderer does not add code Copy chrome | Streaming/cache work remains ours; math wrappers; optional Mermaid uses WebKit |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | No dedicated incremental streaming API documented | Yes / custom integration / no built-in LaTeX advertised | Customizable block styles | Officially in maintenance mode; upstream directs new development to Textual |

**Correction to earlier preliminary research:** Microsoft's renderer **does have syntax highlighting**, confirmed by its `HighlightSwift` dependency and code rendering implementation. An earlier search summary saying it might require a separate highlighting integration was incomplete.

## Shortlist details

### MarkdownView

- `StreamingMarkdownSource` stores complete text snapshots and emits through a newest-value stream. `StreamingMarkdownReader` schedules parsing independently of SwiftUI view updates, supports stable-block reuse and defaults to a 50 ms rendering throttle. `finishStreaming()` triggers final reconciliation; create a new source for each response.
- Public `MarkdownCodeBlockStyle` receives the language and exact code. A PiUI copy-free style replaces the default code presentation throughout the renderer; retain syntax highlighting explicitly in that style. This is smaller than owning recursive Markdown block dispatch merely to remove buttons.
- The default code style includes Copy; it is **not** a no-Copy configuration out of the box.
- Prefer the SwiftUI `MarkdownView` route, not the separate `MarkdownText`/RichText continuous-selection route. The math renderer still wraps native `MTMathUILabel` with `NSViewRepresentable`/`UIViewRepresentable`. This requires explicit approval under the project's AppKit policy.
- Raw HTML blocks can reach `WKWebView`; SVG images have a WebKit path too. Before selection, prove these nodes are neutralized before rendering and all image loading is disabled, including nested/directive cases. Do not call this a WebView-free integration merely because the main view uses SwiftUI.
- Dependencies include swift-markdown, Highlightr, SwiftMath and RichText. The current manifest requires Swift 6.2, compatible with the recorded local toolchain. Verify the selected release manifest and transitive pins in a build spike.

### Textual

- Stronger fit if a mostly SwiftUI text pipeline and minimal custom presentation are preferred. Its default/GitHub code styles already omit Copy; `StructuredText` supports tables, custom styles, highlighting and math attachments.
- Text selection is an optional native interaction layer with AppKit/UIKit overlays; native text layout/rendering and selection implementation are different concerns. Do not describe the whole dependency as having zero AppKit.
- `StructuredText` parses when its markup changes; this is not evidence of tail-only parsing. Cache completed messages and coalesce active-response updates, then measure. Rebuilding every historical message for every token remains unacceptable regardless of renderer.
- Built-in parsing uses Foundation attributed Markdown rather than swift-markdown. Test the required GFM cases, incomplete fences/math, table growth, safe links and image policy rather than assuming complete spec parity.

## Suggested evaluation before changing the design

1. Use the same static and chunked fixtures for MarkdownView and Textual: nested/task lists, tables, Unicode, long fences, display math, malformed content and repeated snapshots.
2. Confirm no Copy controls, no image requests, no active HTML/WebKit rendering and consistent URL allowlisting.
3. Check native Mac/iOS builds and font/appearance behavior. Keep desktop-controlling macOS automation paused; an off-screen/native build spike is not full interaction acceptance.
4. Measure active-response parsing plus unchanged-history parse counts. Prefer a supported library renderer and a small code style over replacing its block tree.

If platform-backed math is acceptable and the HTML/image exclusion gate passes, **MarkdownView is the strongest all-in-one streaming candidate**. If avoiding those view wrappers is more important, test **Textual** next. Do not introduce a custom Markdown renderer just because Copy is deferred.

## Evidence

Inspected upstream READMEs, manifests and source snapshots. Latest tags observed: MarkdownView 3.0.0, Textual 0.5.0, SwiftStreamingMarkdown v0.7.0 and MarkdownExtendedView 1.2.4. Main-branch features are not automatically release guarantees; MarkdownView's streaming source and code-style protocol were also checked at 3.0.0, and Microsoft's Copy code at v0.7.0.

- MarkdownView main inspected at `d24d6b6a5a4dbf210cce5c9f2de70d12cbe73690`: [streaming guide](https://github.com/LiYanan2004/MarkdownView/blob/d24d6b6a5a4dbf210cce5c9f2de70d12cbe73690/Sources/MarkdownView/Documentation.docc/Articles/Rendering-Streaming-Markdown-Content.md), [code style](https://github.com/LiYanan2004/MarkdownView/blob/3.0.0/Sources/MarkdownView/Styles/Code%20Blocks/MarkdownCodeBlockStyle.swift), [math wrapper](https://github.com/LiYanan2004/MarkdownView/blob/d24d6b6a5a4dbf210cce5c9f2de70d12cbe73690/Sources/MarkdownView/Rendering/Shared/Math/SwiftMathView.swift), [HTML block](https://github.com/LiYanan2004/MarkdownView/blob/d24d6b6a5a4dbf210cce5c9f2de70d12cbe73690/Sources/MarkdownView/Rendering/Shared/HTML/HTMLBlockView.swift).
- Textual 0.5.0/main at `01b51875a5406eefc95f52a058cb059e7bc94dc4`: [README](https://github.com/gonzalezreal/textual/tree/0.5.0), [default code style](https://github.com/gonzalezreal/textual/blob/0.5.0/Sources/Textual/StructuredText/Style/Default/DefaultCodeBlockStyle.swift), [StructuredText update path](https://github.com/gonzalezreal/textual/blob/0.5.0/Sources/Textual/StructuredText/StructuredText.swift).
- SwiftStreamingMarkdown main at `95bb755a9b23a1aea8682b9ebc912cb72b176c95`: [README](https://github.com/microsoft/SwiftStreamingMarkdown), [Copy-bearing code view](https://github.com/microsoft/SwiftStreamingMarkdown/blob/v0.7.0/Sources/MarkdownText/UI/CodeBlockView.swift), [manifest](https://github.com/microsoft/SwiftStreamingMarkdown/blob/95bb755a9b23a1aea8682b9ebc912cb72b176c95/Package.swift).
- MarkdownExtendedView main at `3c20f94e1e9ced6d1cd658d8aa32c4ce2312eb8c`: [README](https://github.com/ChrisGVE/MarkdownExtendedView), [parse-in-body path](https://github.com/ChrisGVE/MarkdownExtendedView/blob/3c20f94e1e9ced6d1cd658d8aa32c4ce2312eb8c/Sources/MarkdownExtendedView/MarkdownView.swift).
- [MarkdownUI maintenance notice](https://github.com/gonzalezreal/swift-markdown-ui#readme).
