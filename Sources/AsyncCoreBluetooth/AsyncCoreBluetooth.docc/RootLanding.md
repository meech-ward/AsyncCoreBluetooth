# AsyncCoreBluetooth

@Metadata {
    @TechnologyRoot
    @PageImage(
        purpose: icon, 
        source: "icon", 
        alt: "A technology icon representing the AsyncCoreBluetooth framework."
    )
    @PageColor(green)
}

AsyncCoreBluetooth is a Swift library that wraps CoreBluetooth with a modern Swift concurrency API. It enables you to interact with Bluetooth Low Energy devices using async/await, making your code more readable and easier to maintain.

## Overview

This framework provides a complete async wrapper around Apple's CoreBluetooth framework, allowing you to:

- Scan for peripherals using Swift concurrency
- Establish connections with BLE devices
- Discover services and characteristics
- Read and write characteristic values
- Subscribe to notifications
- Seamlessly integrate with SwiftUI

All with the power and simplicity of Swift's structured concurrency.

## Documentation

Explore the comprehensive documentation to learn how to use AsyncCoreBluetooth:

- [Getting Started Guide](documentation/asynccorebluetooth/gettingstarted)
- [API Reference](documentation/asynccorebluetooth)
- [SwiftUI Integration](documentation/asynccorebluetooth/swiftuiintegration)
- [Error Handling](documentation/asynccorebluetooth/errorhandling)

## Tutorials

Follow step-by-step tutorials to build Bluetooth applications:

- [Creating a BLE Central Application](tutorials/asynccorebluetooth)