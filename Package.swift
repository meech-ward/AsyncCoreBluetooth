// swift-tools-version: 6.0.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AsyncCoreBluetooth",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .watchOS(.v10),
    .tvOS(.v17),
    .visionOS(.v2),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "AsyncCoreBluetooth",
      targets: ["AsyncCoreBluetooth"]
    )
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(url: "https://github.com/meech-ward/IOS-CoreBluetooth-Mock.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
    .package(
      url: "https://github.com/apple/swift-collections.git",
      .upToNextMinor(from: "1.1.0")
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AsyncCoreBluetooth",
      dependencies: [
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]
    ),
    .testTarget(
      name: "AsyncCoreBluetoothTests",
      dependencies: [
        "AsyncCoreBluetooth",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]
    ),
  ]
)
