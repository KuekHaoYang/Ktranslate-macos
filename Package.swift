// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Ktranslate", // Changed
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        .executable( // Changed to executable
            name: "Ktranslate", // Product name
            targets: ["Ktranslate"]) // Points to the executable target
    ],
    dependencies: [
        // No external dependencies yet
    ],
    targets: [
        .target(
            name: "KtranslateCore",
            dependencies: [],
            path: "Ktranslate",
            exclude: ["KtranslateApp.swift", "Info.plist"], // Ensure KtranslateApp.swift is excluded
            sources: nil // Let Swift discover sources, respecting excludes
        ),
        .executableTarget( // New executable target
            name: "Ktranslate", // Executable target name
            dependencies: ["KtranslateCore"], // Depends on the library
            path: "Ktranslate",
            sources: ["KtranslateApp.swift"] // Explicitly include KtranslateApp.swift
        )
        // Test target can be added later
    ]
)
