// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AsyncCoreBluetooth",
  platforms: [
    .iOS(.v13), // Combine was introduced in iOS 13
    .macOS(.v10_15), // Combine was introduced in macOS 10.15
    .watchOS(.v6), // Combine was introduced in watchOS 6
    .tvOS(.v13), // Combine was introduced in tvOS 13
    .visionOS(.v1),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "AsyncCoreBluetooth",
      targets: ["AsyncCoreBluetooth"]
    ),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(name: "CoreBluetoothMock", url: "https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock.git", from: "0.16.1"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AsyncCoreBluetooth",
      dependencies: ["CoreBluetoothMock"]
    ),
    .testTarget(
      name: "AsyncCoreBluetoothTests",
      dependencies: ["AsyncCoreBluetooth", "CoreBluetoothMock"]
    ),
  ]
)
