import SwiftUI
import SwiftStreamingMarkdown

private let prompt = """
Please explain **SwiftUI** with a short example and a comparison table.

- Include `@State`
- Keep the example concise
"""

private let response = """
# SwiftUI example

Use **`@State`** for view-owned values. This is a [link](https://developer.apple.com/xcode/swiftui/).

```swift
struct Counter: View {
    @State private var count = 0

    var body: some View {
        Button("Count: \\(count)") { count += 1 }
    }
}
```

| Feature | Purpose |
| --- | --- |
| `@State` | Local state |
| `Binding` | Shared access |

1. Tap the button.
2. The view updates.

> The streamed response deliberately includes incomplete Markdown while arriving.
"""

private struct SimulatedSource: StreamedMarkdownSource {
    var text: AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                var snapshot = ""
                for character in response {
                    if Task.isCancelled { break }
                    snapshot.append(character)
                    continuation.yield(snapshot)
                    try? await Task.sleep(for: .milliseconds(15))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct ContentView: View {
    @State private var replayID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Markdown streaming spike").font(.headline)
                Spacer()
                Button("Replay") { replayID = UUID() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("USER").font(.caption.bold()).foregroundStyle(.secondary)
                    MarkdownView(text: prompt)
                    Divider()
                    Text("ASSISTANT").font(.caption.bold()).foregroundStyle(.secondary)
                    StreamedMarkdownView(source: SimulatedSource())
                        .id(replayID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 500)
    }
}

@main
struct MarkdownSpikeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
