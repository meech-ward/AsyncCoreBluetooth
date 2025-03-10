# ``AsyncCoreBluetooth/Peripheral``

An actor that represents a remote BLE peripheral device and provides an async interface for discovering and interacting with its services and characteristics.

## Overview

The `Peripheral` class wraps CoreBluetooth's `CBPeripheral` with a Swift concurrency-based API, making it easier to interact with Bluetooth peripherals in a safe and structured way. It provides methods for discovering services and characteristics, reading and writing values, and subscribing to notifications.

### Actor-Based Design

Like `CentralManager`, the `Peripheral` class is implemented as a Swift actor, ensuring that all operations are thread-safe and avoiding common CoreBluetooth concurrency issues.

### Connection States

A peripheral's connection state is represented by the `ConnectionState` enum and can be observed through the `connectionState` property:

```swift
for await state in peripheral.connectionState.stream {
    switch state {
    case .connected:
        print("Connected to \(peripheral.name.current ?? "Unknown Device")")
        // Discover services and interact with the peripheral
    case .disconnected(let error):
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        } else {
            print("Disconnected normally")
        }
    case .connecting:
        print("Connecting...")
    case .disconnecting:
        print("Disconnecting...")
    case .failedToConnect(let error):
        print("Failed to connect: \(error.localizedDescription)")
    }
}
```

### Service and Characteristic Discovery

Once connected, you can discover services and characteristics:

```swift
// Discover services
let heartRateService = try await peripheral.discoverService(BLEIdentifiers.Service.heartRate)

// Discover characteristics
let heartRateMeasurementCharacteristic = try await peripheral.discoverCharacteristic(
    BLEIdentifiers.Characteristic.heartRateMeasurement,
    for: heartRateService
)
```

### Reading and Writing Values

AsyncCoreBluetooth provides async methods for reading and writing characteristic values:

```swift
// Read a characteristic's value
let data = try await peripheral.readValue(for: heartRateCharacteristic)
let heartRate = data[1]
print("Heart rate: \(heartRate) BPM")

// Write to a characteristic with response
try await peripheral.writeValueWithResponse(Data([0x01]), for: controlPointCharacteristic)

// Write to a characteristic without response
try await peripheral.writeValueWithoutResponse(Data([0x01]), for: controlPointCharacteristic)
```

### Subscribing to Notifications

You can subscribe to notifications for value changes:

```swift
// Enable notifications
try await peripheral.setNotifyValue(true, for: heartRateCharacteristic)

// Observe value changes
for await value in heartRateCharacteristic.value.stream {
    guard let data = value else { continue }
    let heartRate = data[1]
    print("Updated heart rate: \(heartRate) BPM")
}

// Later, disable notifications
try await peripheral.setNotifyValue(false, for: heartRateCharacteristic)
```

## Topics

### Peripheral Properties

- ``identifier``
- ``name``
- ``connectionState``

### Discovering Services and Characteristics

- ``discoverServices(_:)``
- ``discoverService(_:)``
- ``discoverCharacteristics(_:for:)``
- ``discoverCharacteristic(_:for:)``
- ``services``

### Reading and Writing Characteristic Values

- ``readValue(for:)``
- ``writeValueWithResponse(_:for:)``
- ``writeValueWithoutResponse(_:for:)``

### Managing Notifications

- ``setNotifyValue(_:for:)``