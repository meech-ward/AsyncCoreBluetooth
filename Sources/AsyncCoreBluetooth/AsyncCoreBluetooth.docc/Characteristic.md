# ``AsyncCoreBluetooth/Characteristic``

A representation of a Bluetooth characteristic, which contains a single value and optional descriptors.

## Overview

Characteristics are the fundamental units of interaction in Bluetooth Low Energy (BLE). Each characteristic represents a specific piece of information or behavior within a service, such as sensor readings, control points, or device states.

In AsyncCoreBluetooth, characteristics are discovered from services on a peripheral:

```swift
// Discover all characteristics in a service
let characteristics = try await peripheral.discoverCharacteristics(nil, for: service)

// Or discover specific characteristics
let heartRateMeasurementCharacteristic = try await peripheral.discoverCharacteristic(
    BLEIdentifiers.Characteristic.heartRateMeasurement,
    for: heartRateService
)
```

### Characteristic Properties

Each characteristic has several key properties:

- **UUID**: A unique identifier for the characteristic
- **Value**: The data contained in the characteristic, accessible via `AsyncObservable`
- **Properties**: Flags indicating what operations are supported (read, write, notify, etc.)
- **IsNotifying**: Whether notifications are enabled for this characteristic

### Reading and Writing Values

AsyncCoreBluetooth provides async methods on the `Peripheral` class to read and write characteristic values:

```swift
// Reading a characteristic's value
let data = try await peripheral.readValue(for: batteryLevelCharacteristic)
let batteryLevel = data.first.map { Int($0) } ?? 0
print("Battery level: \(batteryLevel)%")

// Writing with response (waiting for confirmation)
try await peripheral.writeValueWithResponse(Data([0x01]), for: controlPointCharacteristic)

// Writing without response (no confirmation)
try await peripheral.writeValueWithoutResponse(Data([0x02]), for: controlPointCharacteristic)
```

### Subscribing to Notifications

For characteristics that support notifications or indications, you can subscribe to value changes:

```swift
// Enable notifications
try await peripheral.setNotifyValue(true, for: heartRateCharacteristic)

// Observe value changes using AsyncObservable
for await value in heartRateCharacteristic.value.stream {
    guard let data = value else { continue }
    // Process the updated value
    print("Heart rate updated: \(data)")
}

// In SwiftUI, you can bind to the observable property
Text("Heart Rate: \(String(describing: heartRateCharacteristic.value.observable))")

// Later, disable notifications
try await peripheral.setNotifyValue(false, for: heartRateCharacteristic)
```

### Characteristic Properties

The `properties` property indicates what operations are supported by the characteristic:

```swift
if characteristic.properties.contains(.read) {
    // This characteristic supports read operations
    let value = try await peripheral.readValue(for: characteristic)
}

if characteristic.properties.contains(.notify) {
    // This characteristic supports notifications
    try await peripheral.setNotifyValue(true, for: characteristic)
}

if characteristic.properties.contains(.write) {
    // This characteristic supports write with response
    try await peripheral.writeValueWithResponse(data, for: characteristic)
}

if characteristic.properties.contains(.writeWithoutResponse) {
    // This characteristic supports write without response
    try await peripheral.writeValueWithoutResponse(data, for: characteristic)
}
```

## Topics

### Characteristic Properties

- ``uuid``
- ``value``
- ``properties``
- ``isNotifying``

### Related Methods

- ``Peripheral/readValue(for:)``
- ``Peripheral/writeValueWithResponse(_:for:)``
- ``Peripheral/writeValueWithoutResponse(_:for:)``
- ``Peripheral/setNotifyValue(_:for:)``