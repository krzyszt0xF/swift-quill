// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-quill",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "QuillCore", targets: ["QuillCore"]),
        .library(name: "QuillKit", targets: ["QuillKit"]),
        .library(name: "QuillSwiftUI", targets: ["QuillSwiftUI"]),
        .library(name: "QuillHighlight", targets: ["QuillHighlight"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.0"),
        .package(url: "https://github.com/smittytone/HighlighterSwift.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "QuillCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            exclude: ["README.md"]
        ),
        .target(
            name: "QuillKit",
            dependencies: ["QuillCore"],
            exclude: ["README.md"]
        ),
        .target(
            name: "QuillSwiftUI",
            dependencies: ["QuillKit"],
            exclude: ["README.md"]
        ),
        .target(
            name: "QuillHighlight",
            dependencies: [
                "QuillKit",
                .product(name: "Highlighter", package: "HighlighterSwift"),
            ]
        ),
        .target(
            name: "QuillSharedTestSupport",
            path: "Sources/QuillSharedTestSupport"
        ),
        .target(
            name: "QuillCoreTestSupport",
            dependencies: ["QuillCore", "QuillSharedTestSupport"],
            path: "Sources/QuillCoreTestSupport"
        ),
        .testTarget(
            name: "QuillCoreTests",
            dependencies: ["QuillCore", "QuillCoreTestSupport", "QuillSharedTestSupport"]
        ),
        .testTarget(
            name: "QuillKitTests",
            dependencies: ["QuillKit", "QuillCore", "QuillCoreTestSupport", "QuillSharedTestSupport"]
        ),
        .testTarget(
            name: "QuillSwiftUITests",
            dependencies: ["QuillSwiftUI", "QuillSharedTestSupport"]
        ),
        .testTarget(
            name: "QuillHighlightTests",
            dependencies: ["QuillHighlight", "QuillKit"]
        ),
    ]
)
