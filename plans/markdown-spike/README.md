# SwiftStreamingMarkdown spike

Standalone macOS SwiftUI experiment. It does not change Pi Studio or connect to Pi Server.

Run from the repository root:

```sh
cd plans/markdown-spike
xcodebuild -scheme MarkdownSpike -destination 'platform=macOS' \
  -derivedDataPath /tmp/pi-studio-markdown-spike-xcode -skipMacroValidation build
/tmp/pi-studio-markdown-spike-xcode/Build/Products/Debug/MarkdownSpike
```

The build command trusts the dependency's Equatable compiler macro (`-skipMacroValidation`). Review the dependency before using that option. It uses Xcode to compile the library's asset catalog; `swift run` copied the raw `.xcassets` without an `Assets.car` in our build and may make the text invisible. The Xcode build contains the compiled catalog, but its on-screen result still needs user verification.

The user prompt is static; the response streams one character at a time. Replay restarts it. Inspect incomplete and completed formatting, links, code, tables and text selection. This does not test iOS, real Pi events, reconnection, auto-scroll or performance.

SwiftStreamingMarkdown v0.7.0 is pinned by commit rather than version: SwiftPM rejects its version dependency because the upstream manifest itself uses revision-based dependencies. A revision pin is a spike workaround, not an approved production dependency policy. Its streaming API expects complete growing snapshots, not deltas; its source explicitly reparses each snapshot. UI appearance and selection are not verified by a successful build.
