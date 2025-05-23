// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "KtranslateCore",
    platforms: [
        .macOS(.v13), // Updated
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "KtranslateCore",
            targets: ["KtranslateCore"])
    ],
    dependencies: [
        // No external dependencies yet
    ],
    targets: [
        .target(
            name: "KtranslateCore",
            dependencies: [],
            path: "Ktranslate", // Point to the existing folder where all .swift files are
            exclude: ["KtranslateApp.swift"]
        )
        // We can add a test target later:
        // .testTarget(
        // name: "KtranslateCoreTests",
        // dependencies: ["KtranslateCore"],
        // path: "KtranslateTests" // Assuming tests will be in KtranslateTests folder
        // )
    ]
)
