# SwiftStreamingMarkdown spike

Standalone macOS SwiftUI experiment. It does not change Pi Studio or connect to Pi Server.

Run from the repository root:

```sh
swift run --package-path plans/markdown-spike --scratch-path /tmp/pi-studio-markdown-spike-build MarkdownSpike
```

The user prompt is static; the response streams one character at a time. Replay restarts it. Inspect incomplete and completed formatting, links, code, tables and text selection. This does not test iOS, real Pi events, reconnection, auto-scroll or performance.

SwiftStreamingMarkdown v0.7.0 is pinned by commit rather than version: SwiftPM rejects its version dependency because the upstream manifest itself uses revision-based dependencies. A revision pin is a spike workaround, not an approved production dependency policy. Its streaming API expects complete growing snapshots, not deltas; its source explicitly reparses each snapshot. UI appearance and selection are not verified by a successful build.
