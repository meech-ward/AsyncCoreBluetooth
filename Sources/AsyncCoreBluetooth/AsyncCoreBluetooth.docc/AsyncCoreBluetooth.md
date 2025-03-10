# ``AsyncCoreBluetooth``

A modern Swift concurrency wrapper for CoreBluetooth.

@Metadata {
    @PageImage(
        purpose: icon, 
        source: "icon", 
        alt: "A technology icon representing the AsyncCoreBluetooth framework.")
    @PageColor(green)
}

## Overview

AsyncCoreBluetooth is a Swift library that wraps Apple's CoreBluetooth framework with a modern, concurrency-based API. It allows you to interact with Bluetooth Low Energy (BLE) devices using Swift's async/await pattern, making your code more readable and easier to maintain.

### Key Features

- **Swift Concurrency**: Use async/await instead of delegate callbacks
- **Observable Properties**: Monitor BLE states and values with AsyncObservable
- **SwiftUI Integration**: Easy to use with SwiftUI's state management
- **Type Safety**: Strong typing for BLE operations and error handling
- **Testing Support**: Works with CoreBluetoothMock for unit testing

### Example Usage

```swift
// Initialize central manager
let centralManager = CentralManager()

// Wait for Bluetooth to power on
await centralManager.start().first(where: { $0 == .poweredOn })

// Scan for peripherals
let peripheral = try await centralManager.scanForPeripherals(withServices: nil).first()

// Connect to peripheral
try await centralManager.connect(peripheral)

// Discover services and characteristics
let service = try await peripheral.discoverService(serviceUUID)
let characteristic = try await peripheral.discoverCharacteristic(characteristicUUID, for: service)

// Read and write characteristic values
let data = try await peripheral.readValue(for: characteristic)
try await peripheral.writeValueWithResponse(Data([0x01]), for: characteristic)
```

### Featured

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
}

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:AccessorySetupKit>
- <doc:SwiftUIIntegration>
- <doc:ErrorHandling>

### Core Components

- ``CentralManager``
- ``Peripheral``
- ``Service``
- ``Characteristic``

### Peripheral Management

- ``CentralManager/scanForPeripherals(withServices:options:)``
- ``CentralManager/connect(_:options:)``
- ``CentralManager/cancelPeripheralConnection(_:)``
- ``CentralManager/retrieveConnectedPeripherals(withServices:)``
- ``CentralManager/retrievePeripherals(withIdentifiers:)``
- ``CentralManager/retrievePeripheral(withIdentifier:)``

### BLE State Management

- ``CentralManager/bleState``
- ``CentralManager/start()``

### Services and Characteristics

- ``Peripheral/discoverServices(_:)``
- ``Peripheral/discoverService(_:)``
- ``Peripheral/discoverCharacteristics(_:for:)``
- ``Peripheral/discoverCharacteristic(_:for:)``
- ``Peripheral/readValue(for:)``
- ``Peripheral/writeValueWithResponse(_:for:)``
- ``Peripheral/writeValueWithoutResponse(_:for:)``
- ``Peripheral/setNotifyValue(_:for:)``

### Observable Properties

- ``CentralManager/peripheralsScanned``
- ``Peripheral/connectionState``
- ``Characteristic/value``
- ``Characteristic/isNotifying``

### Error Handling

- ``CentralManagerError``
- ``PeripheralConnectionError``
- ``ServiceError``
- ``CharacteristicError``