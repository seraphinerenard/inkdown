// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownEditor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarkdownEditor",
            path: "Sources",
            resources: [
                .copy("Resources/preview"),
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/AppIcon.png"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MarkdownEditorTests",
            dependencies: ["MarkdownEditor"],
            path: "Tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
