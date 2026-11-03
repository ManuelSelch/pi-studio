// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PiUI",
    platforms: [.iOS("26.1"), .macOS(.v26)],
    products: [.library(name: "PiUI", targets: ["PiUI"])],
    dependencies: [
        .package(url: "https://github.com/ManuelSelch/Router.git", exact: "2.0.0"),
        .package(url: "https://github.com/ManuelSelch/pi-sdk-swift.git", exact: "0.2.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.3"),
        .package(url: "https://github.com/ManuelSelch/Flux.git", exact: "2.0.1"),
        // v0.7.0 declares revision-based dependencies, so SwiftPM requires a revision here.
        .package(url: "https://github.com/microsoft/SwiftStreamingMarkdown", revision: "5f7c04e0558df6146f90d482edb62cb456986bda"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.7.3"),
    ],
    targets: [
        .target(name: "PiUI", dependencies: [
            .product(name: "Router", package: "router"),
            .product(name: "PiSDK", package: "pi-sdk-swift"),
            .product(name: "Flux", package: "Flux"),
            .product(name: "FactoryKit", package: "Factory"),
            .product(name: "SwiftStreamingMarkdown", package: "SwiftStreamingMarkdown"),
            .product(name: "Markdown", package: "swift-markdown"),
        ]),
        .testTarget(name: "PiUITests", dependencies: [
            "PiUI", .product(name: "FluxTestStore", package: "Flux"),
            .product(name: "Router", package: "router"),
            .product(name: "FactoryKit", package: "Factory"),
        ]),
    ]
)
