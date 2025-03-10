# ``AsyncCoreBluetooth/Service``

A representation of a Bluetooth service discovered on a peripheral device.

## Overview

A `Service` represents a collection of data and associated behaviors that accomplish a specific function or feature on a Bluetooth peripheral device. Each service contains one or more characteristics that represent specific pieces of data or behaviors that can be read from or written to.

In AsyncCoreBluetooth, services are obtained by discovering them from a peripheral:

```swift
// Discover all services on a peripheral
let services = try await peripheral.discoverServices(nil)

// Or discover specific services
let heartRateService = try await peripheral.discoverService(CBUUID(string: "180D"))
```

### Service Properties

Each service has several key properties:

- **UUID**: A unique identifier that distinguishes this service from others
- **Primary**: A boolean indicating whether this is a primary or secondary service
- **Characteristics**: An array of characteristics associated with this service

### Primary vs. Secondary Services

- **Primary services** represent the main functionality of a device and are directly discoverable
- **Secondary services** are referenced by primary services and are only accessible through those references

### Working with Services

Once you have discovered services, you typically use them to access their characteristics:

```swift
// Discover all characteristics of a service
let characteristics = try await peripheral.discoverCharacteristics(nil, for: heartRateService)

// Or discover specific characteristics
let heartRateMeasurementCharacteristic = try await peripheral.discoverCharacteristic(
    CBUUID(string: "2A37"), 
    for: heartRateService
)
```

## Topics

### Service Properties

- ``uuid``
- ``isPrimary``
- ``characteristics``

### Related API

- ``Peripheral/discoverServices(_:)``
- ``Peripheral/discoverService(_:)``
- ``Peripheral/discoverCharacteristics(_:for:)``
- ``Peripheral/discoverCharacteristic(_:for:)``