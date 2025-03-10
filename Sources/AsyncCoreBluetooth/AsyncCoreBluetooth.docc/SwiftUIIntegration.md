# SwiftUI Integration

Best practices for integrating AsyncCoreBluetooth with SwiftUI.

## Overview

AsyncCoreBluetooth is designed to work seamlessly with SwiftUI. This guide covers best practices and patterns for integrating Bluetooth functionality into your SwiftUI apps.

### Observable Properties

The `AsyncObservable` type provides `.observable` properties that can be used directly in SwiftUI views:

```swift
struct BLEStateView: View {
    let centralManager = CentralManager()
    
    var body: some View {
        Group {
            switch centralManager.bleState.observable {
            case .poweredOn:
                ScanView(centralManager: centralManager)
            case .poweredOff:
                Text("Please turn on Bluetooth")
            case .unauthorized:
                Text("Please authorize Bluetooth in Settings")
            case .unsupported:
                Text("Bluetooth is not supported on this device")
            default:
                Text("Preparing Bluetooth...")
            }
        }
        .task {
            await centralManager.start()
        }
    }
}
```

### Task Management

Use SwiftUI's `.task` modifier to run async operations when a view appears and automatically cancel them when the view disappears:

```swift
struct ScanView: View {
    let centralManager: CentralManager
    @State private var peripherals: [Peripheral] = []
    
    var body: some View {
        List {
            ForEach(centralManager.peripheralsScanned.observable, id: \.identifier) { peripheral in
                PeripheralRow(peripheral: peripheral, centralManager: centralManager)
            }
        }
        .task {
            try? await centralManager.scanForPeripherals(withServices: nil)
        }
        .onDisappear {
            Task {
                await centralManager.stopScan()
            }
        }
    }
}
```

### Connection Management

Manage peripheral connections with task scopes:

```swift
struct PeripheralView: View {
    let peripheral: Peripheral
    let centralManager: CentralManager
    
    var body: some View {
        Group {
            switch peripheral.connectionState.observable {
            case .connected:
                ServicesView(peripheral: peripheral)
            case .connecting:
                ProgressView("Connecting...")
            case .disconnected:
                Text("Disconnected")
                    .task {
                        try? await centralManager.connect(peripheral)
                    }
            case .failedToConnect(let error):
                Text("Connection failed: \(error.localizedDescription)")
                    .foregroundColor(.red)
            case .disconnecting:
                ProgressView("Disconnecting...")
            }
        }
        .onDisappear {
            if case .connected = peripheral.connectionState.current {
                Task {
                    try? await centralManager.cancelPeripheralConnection(peripheral)
                }
            }
        }
    }
}
```

### Building a BLE Service Manager

For more complex apps, consider creating a service manager to handle BLE operations:

```swift
@Observable
class HeartRateManager {
    private let centralManager = CentralManager()
    private var heartRatePeripheral: Peripheral?
    private var heartRateCharacteristic: Characteristic?
    
    var isScanning = false
    var connectionState: Peripheral.ConnectionState = .disconnected(nil)
    var heartRate: Int?
    
    func startScanning() async {
        do {
            // Wait for Bluetooth to be ready
            await centralManager.start().first(where: { $0 == .poweredOn })
            
            // Scan for heart rate service
            isScanning = true
            let heartRateServiceUUID = CBUUID(string: "180D")
            for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [heartRateServiceUUID]) {
                // Stop on first peripheral found
                heartRatePeripheral = peripheral
                await centralManager.stopScan()
                isScanning = false
                
                // Connect to peripheral
                try await connectToPeripheral()
                break
            }
        } catch {
            print("Error scanning: \(error)")
            isScanning = false
        }
    }
    
    private func connectToPeripheral() async throws {
        guard let peripheral = heartRatePeripheral else { return }
        
        // Observe connection state changes
        Task {
            for await state in peripheral.connectionState.stream {
                connectionState = state
                if case .disconnected = state {
                    heartRate = nil
                }
            }
        }
        
        // Connect to peripheral
        try await centralManager.connect(peripheral)
        
        // Discover services and characteristics
        let heartRateService = try await peripheral.discoverService(CBUUID(string: "180D"))
        let heartRateCharacteristic = try await peripheral.discoverCharacteristic(
            CBUUID(string: "2A37"), 
            for: heartRateService
        )
        
        self.heartRateCharacteristic = heartRateCharacteristic
        
        // Enable notifications
        try await peripheral.setNotifyValue(true, for: heartRateCharacteristic)
        
        // Monitor heart rate values
        Task {
            for await value in heartRateCharacteristic.value.stream {
                guard let data = value, !data.isEmpty else { continue }
                
                // Parse heart rate data per BLE specification
                let firstByte = data[0]
                let isUint16Format = (firstByte & 0x01) == 0x01
                
                if isUint16Format && data.count >= 3 {
                    // Heart rate is in 16-bit format
                    heartRate = Int(data[1]) + (Int(data[2]) << 8)
                } else if data.count >= 2 {
                    // Heart rate is in 8-bit format
                    heartRate = Int(data[1])
                }
            }
        }
    }
    
    func disconnect() async {
        if let peripheral = heartRatePeripheral, case .connected = peripheral.connectionState.current {
            try? await centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}
```

Then use this manager in your SwiftUI views:

```swift
struct HeartRateView: View {
    @State private var manager = HeartRateManager()
    
    var body: some View {
        VStack {
            if let heartRate = manager.heartRate {
                Text("❤️ \(heartRate) BPM")
                    .font(.largeTitle)
            } else {
                switch manager.connectionState {
                case .connected:
                    Text("Waiting for heart rate data...")
                case .connecting:
                    ProgressView("Connecting...")
                case .disconnected:
                    Button("Start Heart Rate Monitor") {
                        Task {
                            await manager.startScanning()
                        }
                    }
                case .failedToConnect(let error):
                    Text("Connection failed: \(error.localizedDescription)")
                        .foregroundColor(.red)
                case .disconnecting:
                    ProgressView("Disconnecting...")
                }
            }
        }
        .padding()
        .onDisappear {
            Task {
                await manager.disconnect()
            }
        }
    }
}
```

## Topics

### Related Articles

- <doc:GettingStarted>

### Related Types

- ``CentralManager``
- ``Peripheral``
- ``Characteristic``