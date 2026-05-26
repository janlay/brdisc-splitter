// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "brdisc-splitter",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "BRDiscSplitter",
      targets: ["BRDiscSplitter"]
    )
  ],
  targets: [
    .executableTarget(
      name: "BRDiscSplitter",
      path: "Sources/BRDiscSplitter",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "BRDiscSplitterTests",
      dependencies: ["BRDiscSplitter"]
    )
  ]
)
