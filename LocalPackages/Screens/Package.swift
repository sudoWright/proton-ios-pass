// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var platforms: [SupportedPlatform] = [
    .macOS(.v12),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v8)
]

let package = Package(
    name: "Screens",
    defaultLocalization: "en",
    platforms: platforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Screens",
            targets: ["Screens"]),
    ],
    dependencies: [
        .package(name: "Core", path: "../Core"),
        .package(name: "Client", path: "../Client"),
        .package(name: "Entities", path: "../Entities"),
        .package(name: "UseCases", path: "../UseCases"),
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Macro", path: "../Macro"),
        .package(url: "https://gitlab.protontech.ch/apple/shared/protoncore.git", exact: "18.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Screens",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "Client", package: "Client"),
                .product(name: "Entities", package: "Entities"),
                .product(name: "UseCases", package: "UseCases"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Macro", package: "Macro"),
                .product(name: "ProtonCoreLoginUI", package: "protoncore")
            ])
    ]
)
