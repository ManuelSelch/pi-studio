// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PiUI",
    platforms: [.iOS("26.1"), .macOS(.v26)],
    products: [.library(name: "PiUI", targets: ["PiUI"])],
    dependencies: [
        .package(path: "../../.dependencies/pi-sdk"),
        .package(url: "https://github.com/hmlongco/Factory.git", exact: "2.5.3"),
        .package(url: "https://github.com/ManuelSelch/Flux.git", revision: "00c8b43799d5acbca04127833daf28f1df2ce477"),
    ],
    targets: [
        .target(name: "PiUI", dependencies: [
            .product(name: "PiSDK", package: "pi-sdk"),
            .product(name: "Flux", package: "Flux"),
            .product(name: "FactoryKit", package: "Factory"),
        ]),
        .testTarget(name: "PiUITests", dependencies: [
            "PiUI", .product(name: "FluxTestStore", package: "Flux"),
            .product(name: "FactoryKit", package: "Factory"),
        ]),
    ]
)
