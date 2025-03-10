# ``AsyncCoreBluetooth/CentralManager``

The core actor responsible for managing BLE operations, scanning for devices, and handling connections.

## Overview

`CentralManager` is the entry point for all Bluetooth Low Energy (BLE) operations in AsyncCoreBluetooth. It provides an async-based interface to CoreBluetooth's functionality, allowing you to scan for peripherals, connect to them, and manage connections using Swift's modern concurrency features.

### Actor-Based Design

The `CentralManager` is implemented as a Swift actor, ensuring all Bluetooth operations are thread-safe. This eliminates common threading issues that can arise when using CoreBluetooth's delegate-based API.

### Observable Properties

The `CentralManager` provides several `AsyncObservable` properties that you can observe over time:

- `bleState`: The current Bluetooth state of the device (poweredOn, poweredOff, etc.)
- `peripheralsScanned`: A collection of peripherals discovered during scanning
- `isScanning`: Whether the central manager is currently scanning

### Example Usage

```swift
// Initialize a CentralManager
let centralManager = CentralManager()

// Start the central manager and wait for Bluetooth to be ready
for await state in await centralManager.start() {
    if state == .poweredOn {
        // Bluetooth is now ready for use
        break
    }
}

// Scan for peripherals with a specific service
let heartRateServiceUUID = CBUUID(string: "180D")
for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [heartRateServiceUUID]) {
    // Process each discovered peripheral
    print("Found peripheral: \(peripheral.name.current ?? "Unknown") (\(peripheral.identifier))")
}

// Connect to a peripheral
let connectionStateStream = try await centralManager.connect(peripheral)
for await state in connectionStateStream {
    switch state {
    case .connected:
        print("Connected successfully!")
    case .failedToConnect(let error):
        print("Failed to connect: \(error)")
    case .disconnected(let error):
        if let error = error {
            print("Disconnected with error: \(error)")
        } else {
            print("Disconnected normally")
        }
    case .connecting:
        print("Connecting...")
    case .disconnecting:
        print("Disconnecting...")
    }
}

// Disconnect from peripheral
try await centralManager.cancelPeripheralConnection(peripheral)
```

## Topics

### Initialization

- ``init(delegate:queue:options:forceMock:)``

### Managing BLE States

- ``start()``
- ``bleState``

### Scanning for Peripherals

- ``scanForPeripherals(withServices:options:)``
- ``scanForPeripheralsStream(withServices:options:)``
- ``stopScan()``
- ``isScanning``
- ``peripheralsScanned``

### Managing Peripheral Connections

- ``connect(_:options:)``
- ``cancelPeripheralConnection(_:)``

### Retrieving Peripherals

- ``retrieveConnectedPeripherals(withServices:)``
- ``retrievePeripherals(withIdentifiers:)``
- ``retrievePeripheral(withIdentifier:)``