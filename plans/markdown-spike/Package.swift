// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownSpike",
    platforms: [.macOS(.v14)],
    dependencies: [
        // A revision is required: the 0.7.0 release uses revision-based dependencies.
        .package(url: "https://github.com/microsoft/SwiftStreamingMarkdown", revision: "5f7c04e0558df6146f90d482edb62cb456986bda")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownSpike",
            dependencies: [.product(name: "SwiftStreamingMarkdown", package: "SwiftStreamingMarkdown")]
        )
    ]
)
