// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "MarkdownEditorKit",
                      platforms: [
                          .iOS(.v17),
                      ],
                      products: [
                          .library(name: "MarkdownEditorKit",
                                   targets: ["MarkdownEditorKit"]),
                      ],
                      targets: [
                          .target(name: "MarkdownEditorKit"),
                          .testTarget(name: "MarkdownEditorKitTests",
                                      dependencies: ["MarkdownEditorKit"]),
                      ],
                      swiftLanguageModes: [.v6])
