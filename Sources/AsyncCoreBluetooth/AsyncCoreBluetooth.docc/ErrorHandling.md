# Error Handling

Best practices for handling errors in AsyncCoreBluetooth.

## Overview

AsyncCoreBluetooth uses Swift's structured error handling to provide clear and actionable errors. This guide covers the error types defined by the library and how to handle them effectively.

### Error Types

AsyncCoreBluetooth defines several error types for different kinds of operations:

- **CentralManagerError**: Errors related to the central manager, such as scanning issues
- **PeripheralConnectionError**: Errors that can occur when connecting to peripherals
- **ServiceError**: Errors related to service discovery and usage
- **CharacteristicError**: Errors related to characteristic operations

### Central Manager Errors

`CentralManagerError` represents errors that can occur when using the central manager:

```swift
// Try to scan for peripherals
do {
    let peripherals = try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID])
    // Process peripherals
} catch CentralManagerError.notPoweredOn {
    // Bluetooth is not powered on
    print("Please enable Bluetooth to scan for devices")
} catch CentralManagerError.alreadyScanning {
    // Another scan is already in progress
    print("Already scanning for peripherals")
} catch {
    print("Unexpected error: \(error)")
}
```

### Connection Errors

Handle errors that can occur when connecting to peripherals:

```swift
do {
    try await centralManager.connect(peripheral)
    print("Connected successfully")
} catch {
    // Connection errors are typically reported through the peripheral's connectionState
    // rather than thrown exceptions, but general errors can still occur
    print("Error connecting to peripheral: \(error)")
}

// The main way to handle connection errors is by observing the peripheral's connectionState
for await state in peripheral.connectionState.stream {
    switch state {
    case .connected:
        print("Connected successfully")
    case .failedToConnect(let error):
        print("Failed to connect: \(error.localizedDescription)")
        if let cbError = error as? CBError, cbError.code == .connectionTimeout {
            print("Connection timed out. The device might be out of range.")
        }
    case .disconnected(let error):
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        } else {
            print("Disconnected normally")
        }
    default:
        break
    }
}
```

### Service and Characteristic Errors

Handle errors related to service and characteristic operations:

```swift
// Service discovery
do {
    let services = try await peripheral.discoverServices([targetServiceUUID])
    // Process services
} catch ServiceError.serviceDiscoveryTimeout {
    print("Service discovery timed out")
} catch {
    print("Service discovery error: \(error)")
}

// Characteristic discovery
do {
    let characteristics = try await peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
    // Process characteristics
} catch CharacteristicError.characteristicDiscoveryTimeout {
    print("Characteristic discovery timed out")
} catch {
    print("Characteristic discovery error: \(error)")
}

// Reading characteristic values
do {
    let value = try await peripheral.readValue(for: characteristic)
    // Process value
} catch CharacteristicError.readTimeout {
    print("Read timed out")
} catch CharacteristicError.readFailed(let error) {
    print("Read failed: \(error)")
} catch {
    print("Unexpected error: \(error)")
}

// Writing characteristic values
do {
    try await peripheral.writeValueWithResponse(data, for: characteristic)
    print("Write successful")
} catch CharacteristicError.writeTimeout {
    print("Write timed out")
} catch CharacteristicError.writeFailed(let error) {
    print("Write failed: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Using MightFail for Better Error Handling

The example code shows the use of a MightFail package for concise error handling:

```swift
// Enable notifications with MightFail
let (error, _, success) = await mightFail { 
    try await peripheral.setNotifyValue(enabled, for: heartRateMeasurementCharacteristic)
}

if success {
    print("Notifications enabled successfully")
} else if let error = error {
    print("Failed to enable notifications: \(error)")
}
```

### Comprehensive Error Handling Example

Here's a more comprehensive example showing how to handle errors at different stages of BLE interaction:

```swift
class BLEManager {
    private let centralManager = CentralManager()
    
    func connectAndReadValue() async {
        // 1. Start the central manager
        do {
            let state = await centralManager.start().first(where: { $0 == .poweredOn })
            if state != .poweredOn {
                print("Bluetooth is not powered on: \(state)")
                return
            }
        } catch {
            print("Error starting central manager: \(error)")
            return
        }
        
        // 2. Scan for peripherals
        var targetPeripheral: Peripheral?
        do {
            for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [targetServiceUUID]) {
                targetPeripheral = peripheral
                await centralManager.stopScan()
                break
            }
        } catch CentralManagerError.notPoweredOn {
            print("Cannot scan: Bluetooth is not powered on")
            return
        } catch CentralManagerError.alreadyScanning {
            print("Already scanning for peripherals")
            await centralManager.stopScan()
            // Try again
            return
        } catch {
            print("Scan error: \(error)")
            return
        }
        
        guard let peripheral = targetPeripheral else {
            print("No peripheral found with the target service")
            return
        }
        
        // 3. Connect to peripheral
        do {
            try await centralManager.connect(peripheral)
            
            // Wait for connection to complete
            let connectionState = try await peripheral.connectionState.stream.first(where: { 
                if case .connected = $0 { return true }
                if case .failedToConnect = $0 { return true }
                return false
            })
            
            if case .failedToConnect(let error) = connectionState {
                print("Failed to connect: \(error)")
                return
            }
        } catch {
            print("Connection error: \(error)")
            return
        }
        
        // 4. Discover services
        var targetService: Service?
        do {
            let services = try await peripheral.discoverServices([targetServiceUUID])
            targetService = services.first
        } catch {
            print("Service discovery error: \(error)")
            try? await centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let service = targetService else {
            print("Target service not found on peripheral")
            try? await centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        // 5. Discover characteristics
        var targetCharacteristic: Characteristic?
        do {
            let characteristics = try await peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
            targetCharacteristic = characteristics.first
        } catch {
            print("Characteristic discovery error: \(error)")
            try? await centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let characteristic = targetCharacteristic else {
            print("Target characteristic not found in service")
            try? await centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        // 6. Read characteristic value
        do {
            let value = try await peripheral.readValue(for: characteristic)
            print("Successfully read value: \(value)")
        } catch {
            print("Error reading characteristic: \(error)")
        }
        
        // 7. Clean up
        try? await centralManager.cancelPeripheralConnection(peripheral)
    }
}
```

## Topics

### Related Articles

- <doc:GettingStarted>

### Related Types

- ``CentralManager``
- ``Peripheral``
- ``Service``
- ``Characteristic``