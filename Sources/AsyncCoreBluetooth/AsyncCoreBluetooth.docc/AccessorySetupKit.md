# Integrating with Accessory Setup Kit

Learn how to use AsyncCoreBluetooth with Apple's Accessory Setup Kit.

@Metadata {
    @PageImage(purpose: card, source: "icon", alt: "Async Core Bluetooth")
}

## Overview

This guide explains how to use AsyncCoreBluetooth in conjunction with Apple's Accessory Setup Kit for seamless accessory setup experiences.

### What is Accessory Setup Kit?

Accessory Setup Kit (ASK) is Apple's framework for creating a consistent and secure setup experience for accessories. It's commonly used for HomeKit accessories but can be used for other types of accessories as well.

### Using AsyncCoreBluetooth with Accessory Setup Kit

When building an app that sets up Bluetooth accessories and uses the Accessory Setup Kit, you can leverage AsyncCoreBluetooth to handle the Bluetooth communication while ASK handles the setup flow.

### Initializing with ASK

First, create and activate an ASK session while also setting up AsyncCoreBluetooth:

```swift
import AsyncCoreBluetooth
import AccessorySetupKit

class AccessorySetupCoordinator {
    // AsyncCoreBluetooth central manager
    private let centralManager = CentralManager()
    
    // ASK session
    private var askSession: ASAccessorySession?
    
    func startSetup() async {
        // Initialize AsyncCoreBluetooth
        await centralManager.start().first(where: { $0 == .poweredOn })
        
        // Create and activate ASK session
        askSession = ASAccessorySession()
        askSession?.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent(event:))
    }
    
    func handleSessionEvent(event: ASAccessoryEvent) {  
        switch event.eventType {
        case .activated:
            print("ASK Session is activated and ready to use")
            Task {
                await startBluetoothScan()
            }
        default:
            print("Received ASK event type \(event.eventType)")
        }
    }
    
    // Start scanning for BLE devices with AsyncCoreBluetooth
    private func startBluetoothScan() async {
        do {
            try await centralManager.scanForPeripherals(withServices: nil)
            // Process discovered peripherals...
        } catch {
            print("Scan error: \(error)")
        }
    }
}
```

### Creating Accessory Descriptors

Use ASK descriptors to help users select the right accessory during setup:

```swift 
// Create descriptor for different accessories
func createAccessoryPickerItems() -> [ASPickerDisplayItem] {
    // Create descriptor for first accessory type
    let accessory1Descriptor = ASDiscoveryDescriptor()
    accessory1Descriptor.bluetoothServiceUUID = CBUUID(string: "YOUR-SERVICE-UUID-1")
    
    // Create descriptor for second accessory type
    let accessory2Descriptor = ASDiscoveryDescriptor()
    accessory2Descriptor.bluetoothServiceUUID = CBUUID(string: "YOUR-SERVICE-UUID-2")
    
    // Create picker display items
    let accessory1Item = ASPickerDisplayItem(
        name: "Accessory Type 1",
        productImage: UIImage(named: "accessory1")!,
        descriptor: accessory1Descriptor
    )
    
    let accessory2Item = ASPickerDisplayItem(
        name: "Accessory Type 2",
        productImage: UIImage(named: "accessory2")!,
        descriptor: accessory2Descriptor
    )
    
    return [accessory1Item, accessory2Item]
}
```

### Coordinating ASK and AsyncCoreBluetooth

When the user selects an accessory, use AsyncCoreBluetooth to connect and communicate:

```swift
func userSelectedAccessory(withUUID serviceUUID: CBUUID) async {
    // Use AsyncCoreBluetooth to find and connect to the accessory
    do {
        // Scan for the specific service UUID
        for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [serviceUUID]) {
            await centralManager.stopScan()
            
            // Connect to peripheral
            try await centralManager.connect(peripheral)
            
            // Wait for connection
            let connected = await waitForConnection(peripheral)
            if connected {
                // Successfully connected, proceed with ASK setup
                await performSetupWithASK(peripheral)
            }
            
            break
        }
    } catch {
        print("Error during BLE operations: \(error)")
        // Notify ASK about the failure
        askSession?.notifyEvent(.setupFailed, userInfo: ["error": error])
    }
}

private func waitForConnection(_ peripheral: Peripheral) async -> Bool {
    for await state in peripheral.connectionState.stream {
        if case .connected = state {
            return true
        } else if case .failedToConnect = state {
            return false
        }
    }
    return false
}

private func performSetupWithASK(_ peripheral: Peripheral) async {
    do {
        // Discover services and characteristics
        let services = try await peripheral.discoverServices(nil)
        
        // Find the setup service and characteristics
        // ... (code to find and interact with specific characteristics)
        
        // Extract setup information and provide it to ASK
        // askSession?.notifyEvent(.accessoryFound, userInfo: ["setupInfo": setupInfo])
        
        // Handle ASK setup completion
        // ...
    } catch {
        print("Setup error: \(error)")
        askSession?.notifyEvent(.setupFailed, userInfo: ["error": error])
    }
}
```

### Full Integration Example

A more complete example of the integration flow:

```swift
class IntegratedSetupManager {
    private let centralManager = CentralManager()
    private var askSession: ASAccessorySession?
    private var currentPeripheral: Peripheral?
    
    // Start the entire setup process
    func beginSetup() async {
        // 1. Initialize AsyncCoreBluetooth
        await centralManager.start().first(where: { $0 == .poweredOn })
        
        // 2. Initialize ASK
        askSession = ASAccessorySession()
        
        // 3. Create display items for accessory picker
        let displayItems = createAccessoryPickerItems()
        
        // 4. Activate ASK session
        askSession?.activate(on: DispatchQueue.main) { [weak self] event in
            guard let self = self else { return }
            
            Task {
                await self.handleASKEvent(event)
            }
        }
        
        // 5. Present accessory picker
        askSession?.presentAccessoryPicker(displayItems: displayItems)
    }
    
    // Handle ASK events
    private func handleASKEvent(_ event: ASAccessoryEvent) async {
        switch event.eventType {
        case .accessorySelected:
            if let descriptor = event.userInfo?["descriptor"] as? ASDiscoveryDescriptor,
               let serviceUUID = descriptor.bluetoothServiceUUID {
                await findAndConnectToAccessory(withServiceUUID: serviceUUID)
            }
            
        case .setupCompleted:
            // Clean up BLE connections
            if let peripheral = currentPeripheral {
                try? await centralManager.cancelPeripheralConnection(peripheral)
            }
            
        case .setupCancelled:
            // Clean up BLE connections
            if let peripheral = currentPeripheral {
                try? await centralManager.cancelPeripheralConnection(peripheral)
            }
            
        default:
            break
        }
    }
    
    // Find and connect to an accessory
    private func findAndConnectToAccessory(withServiceUUID serviceUUID: CBUUID) async {
        do {
            // Scan for the accessory
            for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [serviceUUID]) {
                await centralManager.stopScan()
                currentPeripheral = peripheral
                
                // Connect and proceed with setup
                try await establishConnectionAndSetup(peripheral)
                break
            }
        } catch {
            askSession?.notifyEvent(.setupFailed, userInfo: ["error": error])
        }
    }
    
    // Establish connection and perform setup
    private func establishConnectionAndSetup(_ peripheral: Peripheral) async throws {
        // Connect to peripheral
        try await centralManager.connect(peripheral)
        
        // Monitor connection state
        for await state in peripheral.connectionState.stream {
            if case .connected = state {
                // Connected successfully, proceed with ASK setup
                try await performSetupSteps(peripheral)
                break
            } else if case .failedToConnect(let error) = state {
                throw error
            }
        }
    }
    
    // Perform the actual setup steps
    private func performSetupSteps(_ peripheral: Peripheral) async throws {
        // Implementation of the specific setup steps for your accessory
        // ...
        
        // Notify ASK of completion
        askSession?.notifyEvent(.setupCompleted)
    }
}
```

## Topics

### Related Articles

- <doc:GettingStarted>

### Related Types

- ``CentralManager``
- ``Peripheral``