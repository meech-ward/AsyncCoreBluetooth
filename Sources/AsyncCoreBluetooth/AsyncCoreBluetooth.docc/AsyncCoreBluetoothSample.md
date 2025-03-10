# Sample Code for AsyncCoreBluetooth

Learn through example code showing real-world usage of AsyncCoreBluetooth.

## Overview

This article provides sample code excerpts demonstrating how to use AsyncCoreBluetooth in common scenarios. For complete examples, refer to the example project included with the library.

### Basic Scanning and Connection

Here's a complete example showing how to scan for, connect to, and interact with a BLE peripheral:

```swift
import AsyncCoreBluetooth

class BLEManager {
    private let centralManager = CentralManager()
    
    func startScan() async {
        // Wait for Bluetooth to be ready
        await centralManager.start().first(where: { $0 == .poweredOn })
        
        // Start scanning for devices
        do {
            print("Scanning for peripherals...")
            for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: nil) {
                print("Found: \(peripheral.name.current ?? "Unknown") (\(peripheral.identifier))")
                
                // Connect to the first peripheral found
                await centralManager.stopScan()
                try await connectToPeripheral(peripheral)
                break
            }
        } catch {
            print("Scan error: \(error)")
        }
    }
    
    private func connectToPeripheral(_ peripheral: Peripheral) async throws {
        print("Connecting to \(peripheral.name.current ?? "Unknown")...")
        
        // Connect to the peripheral
        try await centralManager.connect(peripheral)
        
        // Wait for connection to be established
        for await state in peripheral.connectionState.stream {
            if case .connected = state {
                print("Connected!")
                try await discoverServices(peripheral)
                break
            } else if case .failedToConnect(let error) = state {
                print("Failed to connect: \(error)")
                throw error
            }
        }
    }
    
    private func discoverServices(_ peripheral: Peripheral) async throws {
        // Discover all services
        let services = try await peripheral.discoverServices(nil)
        print("Discovered \(services.count) services")
        
        for service in services {
            print("Service: \(service.uuid)")
            
            // Discover characteristics for each service
            let characteristics = try await peripheral.discoverCharacteristics(nil, for: service)
            
            for characteristic in characteristics {
                print("  Characteristic: \(characteristic.uuid)")
                
                // Read the characteristic value if it supports reading
                if characteristic.properties.contains(.read) {
                    let value = try await peripheral.readValue(for: characteristic)
                    print("    Value: \(value.hexString)")
                }
                
                // Enable notifications if supported
                if characteristic.properties.contains(.notify) {
                    try await peripheral.setNotifyValue(true, for: characteristic)
                    print("    Notifications enabled")
                    
                    // Monitor value changes
                    Task {
                        for await value in characteristic.value.stream {
                            guard let data = value else { continue }
                            print("    Notification value: \(data.hexString)")
                        }
                    }
                }
            }
        }
    }
    
    func disconnect(_ peripheral: Peripheral) async {
        try? await centralManager.cancelPeripheralConnection(peripheral)
        print("Disconnected")
    }
}

// Extension to show Data values as hexadecimal strings
extension Data {
    var hexString: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
```

### SwiftUI Integration Example

Here's how to integrate AsyncCoreBluetooth with SwiftUI:

```swift
import SwiftUI
import AsyncCoreBluetooth

struct BLEScannerView: View {
    @State private var centralManager = CentralManager()
    @State private var selectedPeripheral: Peripheral?
    
    var body: some View {
        NavigationStack {
            VStack {
                // Show BLE state
                Group {
                    switch centralManager.bleState.observable {
                    case .poweredOn:
                        if centralManager.isScanning.observable {
                            ProgressView("Scanning...")
                        } else {
                            Button("Start Scanning") {
                                Task {
                                    try? await centralManager.scanForPeripherals(withServices: nil)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    case .poweredOff:
                        Text("Bluetooth is turned off")
                            .foregroundColor(.red)
                    default:
                        Text("Bluetooth state: \(String(describing: centralManager.bleState.observable))")
                    }
                }
                .padding()
                
                // Show discovered peripherals
                List {
                    ForEach(centralManager.peripheralsScanned.observable, id: \.identifier) { peripheral in
                        NavigationLink {
                            PeripheralDetailView(peripheral: peripheral, centralManager: centralManager)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(peripheral.name.current ?? "Unknown Device")
                                    .font(.headline)
                                Text(peripheral.identifier.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("BLE Scanner")
            .toolbar {
                Button {
                    Task {
                        await centralManager.stopScan()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .disabled(!centralManager.isScanning.observable)
            }
            .task {
                await centralManager.start()
            }
        }
    }
}

struct PeripheralDetailView: View {
    let peripheral: Peripheral
    let centralManager: CentralManager
    @State private var services: [Service] = []
    
    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: peripheral.name.current ?? "Unknown")
                LabeledContent("Identifier", value: peripheral.identifier.uuidString)
                LabeledContent("State") {
                    ConnectionStateView(state: peripheral.connectionState.observable)
                }
            } header: {
                Text("Device Info")
            }
            
            Section {
                ForEach(services, id: \.uuid) { service in
                    NavigationLink {
                        ServiceDetailView(peripheral: peripheral, service: service)
                    } label: {
                        Text(service.uuid.description)
                    }
                }
            } header: {
                Text("Services")
            }
        }
        .navigationTitle("Device Details")
        .task {
            // Connect to peripheral
            try? await centralManager.connect(peripheral)
            
            // Wait for connection
            for await state in peripheral.connectionState.stream {
                if case .connected = state {
                    // Discover services
                    do {
                        services = try await peripheral.discoverServices(nil)
                    } catch {
                        print("Error discovering services: \(error)")
                    }
                    break
                }
            }
        }
        .onDisappear {
            Task {
                try? await centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
}

struct ConnectionStateView: View {
    let state: Peripheral.ConnectionState
    
    var body: some View {
        switch state {
        case .connected:
            Text("Connected")
                .foregroundColor(.green)
        case .connecting:
            HStack {
                Text("Connecting...")
                ProgressView()
            }
            .foregroundColor(.orange)
        case .disconnected:
            Text("Disconnected")
                .foregroundColor(.red)
        case .disconnecting:
            HStack {
                Text("Disconnecting...")
                ProgressView()
            }
            .foregroundColor(.orange)
        case .failedToConnect(let error):
            Text("Failed to connect: \(error.localizedDescription)")
                .foregroundColor(.red)
        }
    }
}

struct ServiceDetailView: View {
    let peripheral: Peripheral
    let service: Service
    @State private var characteristics: [Characteristic] = []
    
    var body: some View {
        List {
            Section {
                LabeledContent("UUID", value: service.uuid.description)
                LabeledContent("Is Primary", value: service.isPrimary ? "Yes" : "No")
            } header: {
                Text("Service Info")
            }
            
            Section {
                ForEach(characteristics, id: \.uuid) { characteristic in
                    NavigationLink {
                        CharacteristicDetailView(peripheral: peripheral, characteristic: characteristic)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(characteristic.uuid.description)
                            
                            HStack {
                                if characteristic.properties.contains(.read) {
                                    Image(systemName: "r.circle")
                                }
                                if characteristic.properties.contains(.write) {
                                    Image(systemName: "w.circle")
                                }
                                if characteristic.properties.contains(.notify) {
                                    Image(systemName: "bell.circle")
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Characteristics")
            }
        }
        .navigationTitle("Service Details")
        .task {
            do {
                characteristics = try await peripheral.discoverCharacteristics(nil, for: service)
            } catch {
                print("Error discovering characteristics: \(error)")
            }
        }
    }
}

struct CharacteristicDetailView: View {
    let peripheral: Peripheral
    let characteristic: Characteristic
    @State private var writeValue = "01"
    @State private var isNotifying = false
    
    var body: some View {
        List {
            Section {
                LabeledContent("UUID", value: characteristic.uuid.description)
                LabeledContent("Properties") {
                    Text(propertiesString)
                }
                LabeledContent("Notifications", value: characteristic.isNotifying.observable ? "Enabled" : "Disabled")
            } header: {
                Text("Characteristic Info")
            }
            
            if characteristic.properties.contains(.read) {
                Section {
                    if let data = characteristic.value.observable {
                        Text(data.hexString)
                    } else {
                        Text("No value")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Read Value") {
                        Task {
                            try? await peripheral.readValue(for: characteristic)
                        }
                    }
                } header: {
                    Text("Value")
                }
            }
            
            if characteristic.properties.contains(.notify) {
                Section {
                    Toggle("Enable Notifications", isOn: $isNotifying)
                        .onChange(of: isNotifying) { _, newValue in
                            Task {
                                try? await peripheral.setNotifyValue(newValue, for: characteristic)
                            }
                        }
                } header: {
                    Text("Notifications")
                }
            }
            
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                Section {
                    TextField("Hex Value (e.g. 01AB)", text: $writeValue)
                    
                    if characteristic.properties.contains(.write) {
                        Button("Write with Response") {
                            Task {
                                guard let data = Data(hexString: writeValue) else { return }
                                try? await peripheral.writeValueWithResponse(data, for: characteristic)
                            }
                        }
                    }
                    
                    if characteristic.properties.contains(.writeWithoutResponse) {
                        Button("Write without Response") {
                            Task {
                                guard let data = Data(hexString: writeValue) else { return }
                                try? await peripheral.writeValueWithoutResponse(data, for: characteristic)
                            }
                        }
                    }
                } header: {
                    Text("Write Value")
                }
            }
        }
        .navigationTitle("Characteristic")
        .task {
            isNotifying = characteristic.isNotifying.current
            
            if characteristic.properties.contains(.read) {
                try? await peripheral.readValue(for: characteristic)
            }
        }
    }
    
    var propertiesString: String {
        var props: [String] = []
        let properties = characteristic.properties
        
        if properties.contains(.read) { props.append("Read") }
        if properties.contains(.write) { props.append("Write") }
        if properties.contains(.writeWithoutResponse) { props.append("Write Without Response") }
        if properties.contains(.notify) { props.append("Notify") }
        if properties.contains(.indicate) { props.append("Indicate") }
        if properties.contains(.broadcast) { props.append("Broadcast") }
        
        return props.joined(separator: ", ")
    }
}

// Extension to convert hex strings to Data
extension Data {
    init?(hexString: String) {
        let hexString = hexString.replacingOccurrences(of: " ", with: "")
        guard hexString.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hexString.startIndex
        
        while index < hexString.endIndex {
            let byteString = hexString[index..<hexString.index(index, offsetBy: 2)]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = hexString.index(index, offsetBy: 2)
        }
        
        self = data
    }
}
```

For complete working examples, refer to the example projects included in the AsyncCoreBluetooth repository.

## Topics

### Related Documentation

- <doc:GettingStarted>
- <doc:SwiftUIIntegration>
- <doc:ErrorHandling>

### Related Types

- ``CentralManager``
- ``Peripheral``
- ``Service``
- ``Characteristic``