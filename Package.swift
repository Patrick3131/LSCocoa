// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LSCocoa",
    platforms: [
        .iOS(.v13), .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LSCocoa",
            targets: ["LSCocoa"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Patrick3131/LSData.git", .branch("dev_p"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LSCocoa",
            dependencies: [.product(name: "LSData", package: "LSData")]),
        .testTarget(
            name: "LSCocoaTests",
            dependencies: ["LSCocoa"]),
    ]
)
