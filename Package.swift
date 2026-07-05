// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FindMe",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FindMeCore", targets: ["FindMeCore"])
    ],
    targets: [
        .target(name: "FindMeCore"),
        .testTarget(name: "FindMeCoreTests", dependencies: ["FindMeCore"])
    ]
)
