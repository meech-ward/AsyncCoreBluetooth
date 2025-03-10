# Observable Properties

A powerful pattern for monitoring values over time in AsyncCoreBluetooth.

## Overview

AsyncCoreBluetooth uses a property wrapper called `AsyncObservable` that makes it easy to observe Bluetooth state changes and device values. It wraps a value and provides three different ways to access it:

1. **Current Value**: Access the latest value through the `.current` property
2. **AsyncStream**: Observe value changes over time through the `.stream` property
3. **SwiftUI Binding**: Use the `.observable` property for SwiftUI integration

This versatility makes it suitable for different programming patterns and integrations.

### Accessing the Current Value

The simplest way to use an `AsyncObservable` is to access its current value:

```swift
let bleState = centralManager.bleState.current
if bleState == .poweredOn {
    // Bluetooth is ready to use
}

let connectionState = peripheral.connectionState.current
if case .connected = connectionState {
    // Device is connected
}
```

### Streaming Values Over Time

To observe changes over time, use the `.stream` property with Swift's `for await` syntax:

```swift
// Monitor Bluetooth state changes
for await state in centralManager.bleState.stream {
    switch state {
    case .poweredOn:
        print("Bluetooth is powered on and ready")
        // Start scanning or other Bluetooth operations
    case .poweredOff:
        print("Bluetooth is powered off")
        // Update UI to prompt user to enable Bluetooth
    case .unauthorized:
        print("App is not authorized to use Bluetooth")
        // Show permissions request UI
    default:
        print("Other Bluetooth state: \(state)")
    }
}

// Monitor connection state changes
for await state in peripheral.connectionState.stream {
    switch state {
    case .connected:
        print("Connected to peripheral")
    case .disconnected(let error):
        if let error = error {
            print("Disconnected with error: \(error)")
        } else {
            print("Disconnected normally")
        }
    default:
        print("Other connection state: \(state)")
    }
}

// Monitor characteristic value changes
try await peripheral.setNotifyValue(true, for: characteristic)
for await value in characteristic.value.stream {
    guard let data = value else { continue }
    // Process the new data
    print("New value received: \(data)")
}
```

### SwiftUI Integration

The `.observable` property makes it easy to integrate with SwiftUI:

```swift
struct BLEStateView: View {
    var centralManager: CentralManager
    
    var body: some View {
        VStack {
            switch centralManager.bleState.observable {
            case .poweredOn:
                Text("Bluetooth is on")
                    .foregroundColor(.green)
            case .poweredOff:
                Text("Bluetooth is off")
                    .foregroundColor(.red)
            case .unauthorized:
                Text("Bluetooth permissions required")
                    .foregroundColor(.orange)
            default:
                Text("Bluetooth state: \(String(describing: centralManager.bleState.observable))")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .task {
            await centralManager.start()
        }
    }
}

struct CharacteristicValueView: View {
    var characteristic: Characteristic
    var peripheral: Peripheral
    
    var body: some View {
        VStack {
            if let data = characteristic.value.observable {
                Text("Value: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            } else {
                Text("No value")
            }
            
            Button("Read Value") {
                Task {
                    try? await peripheral.readValue(for: characteristic)
                }
            }
        }
    }
}
```

## Topics

### Common Observable Properties

- ``CentralManager/bleState``
- ``CentralManager/peripheralsScanned``
- ``CentralManager/isScanning``
- ``Peripheral/connectionState``
- ``Peripheral/name``
- ``Characteristic/value``
- ``Characteristic/isNotifying``