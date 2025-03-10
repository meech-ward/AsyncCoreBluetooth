// swift-tools-version: 6.0.0

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
    .library(
      name: "AsyncCoreBluetooth",
      targets: ["AsyncCoreBluetooth"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/meech-ward/IOS-CoreBluetooth-Mock.git", branch: "main"),
   .package(url: "https://github.com/meech-ward/AsyncObservable.git", branch: "main"),
    // .package(path: "../AsyncObservable"),
    .package(
      url: "https://github.com/apple/swift-collections.git",
      .upToNextMinor(from: "1.1.0")
    ),
  ],
  targets: [
    .target(
      name: "AsyncCoreBluetooth",
      dependencies: [
        .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
        .product(name: "AsyncObservable", package: "AsyncObservable"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]
    ),
    .testTarget(
      name: "AsyncCoreBluetoothTests",
      dependencies: [
        "AsyncCoreBluetooth",
        .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
        .product(name: "AsyncObservable", package: "AsyncObservable"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]
    ),
  ]
)
