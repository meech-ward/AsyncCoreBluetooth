# Getting Started with Async Core Bluetooth

Async Core Bluetooth

@Metadata {
    @PageImage(purpose: card, source: "icon", alt: "Async Core Bluetooth")
}

## Overview

Async Core Bluetooth

### Initializing The Central Manager

Setup the central manager and check the current ble state:

```swift
import AsyncCoreBluetooth

let centralManager = CentralManager()

for await bleState in await centralManager.startStream() {
  switch bleState {
    case .unknown:
      print("Unkown")
    case .resetting:
      print("Resetting")
    case .unsupported:
      print("Unsupported")
    case .unauthorized:
      print("Unauthorized")
    case .poweredOff:
      print("Powered Off")
    case .poweredOn:
      print("Powered On, ready to scan")
  }
}
```

`CentralManager` also provides a `@Published` property for the ble state to make it easy to use with SwiftUI:

```swift
import AsyncCoreBluetooth

struct ContentView: View {
  @StateObject var centralManager = CentralManager()
  var body: some View {
    NavigationStack {
      VStack {
        switch centralManager.bleState {
        case .unknown:
          Text("Unkown")
        case .resetting:
          Text("Resetting")
        case .unsupported:
          Text("Unsupported")
        case .unauthorized:
          Text("Unauthorized")
        case .poweredOff:
          Text("Powered Off")
        case .poweredOn:
            Text("Powered On, ready to scan")
        }
      }
      .padding()
      .navigationTitle("App")
    }
    .task {
      await centralManager.start()
    }
  }
}
```

### Scanning or Stopping Scans of Peripherals

```swift
import AsyncCoreBluetooth

let heartRateServiceUUID = UUID(string: "180D")

do {
  for await peripheral in try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID]) {
    print("found peripheral \(peripheral)")
    // break out of the loop or terminate the continuation to stop the scan
  }
} catch {
  // This only happens when ble state is not powered on or you're already scanning
  print("error scanning for peripherals \(error)")
}
```

SwiftUI:

```swift
import AsyncCoreBluetooth

struct ScanningPeripherals: View {
  let heartRateServiceUUID = UUID(string: "180D")
  @ObservedObject var centralManager: CentralManager
  @MainActor @State private var peripherals: Set<Peripheral> = []

  var body: some View {
    VStack {
      List(Array(peripherals), id: \.identifier) { peripheral in
        Section {
          ScannedPeripheralRow(centralManager: centralManager, peripheral: peripheral)
        }
      }
    }
    .task {
      do {
        for await peripheral in try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID]) {
          peripherals.insert(peripheral)
          // break out of the loop or terminate the continuation to stop the scan
        }
      } catch {
        // This only happens when ble state is not powered on or you're already scanning
        print("error scanning for peripherals \(error)")
      }
    }
  }
}
```

### Establishing or Canceling Connections with Peripherals

Just like `CBCentralManager`, the `CentralManager` has a `connect` and `cancelPeripheralConnection` method. However, both of these methods return a discardable `AsyncStream` that you can use to monitor the connection state of the peripheral.

```swift
@discardableResult public func connect(_ peripheral: Peripheral, options: [String: Any]? = nil) async throws -> AsyncStream<Peripheral.ConnectionState> {
@discardableResult public func cancelPeripheralConnection(_ peripheral: Peripheral) async throws -> AsyncStream<Peripheral.ConnectionState> {
```

```swift
enum ConnectionState {
  case disconnected(CBError?)
  case connecting
  case connected
  case disconnecting
  case failedToConnect(CBError)
}
```

* Defaults to `disconnected(nil)`
* Calling `connect()` on the central manager will cause the connectionState to change to connecting
* After conencting, the device will change to connected or `failedToConnect()`
* Calling `disconnect()` on the central manager will cause the connectionState to change to `disconnecting`
* After `disconnecting`, the device will change to `disconnected(nil)`
* If the device disconnects unexpectedly, the device will change straight from connected to `disconnected(error)`

There's also the following method so you can grab an `AsyncStream<Peripheral.ConnectionState>` for a peripheral at any time:

```swift
func connectionState(forPeripheral peripheral: Peripheral) async -> AsyncStream<Peripheral.ConnectionState>
```

On top of that, `peripheral.connectionState` is a `@Published` property for the connection state to make it easy to use with SwiftUI:


```swift
let centralManager = CentralManager()

await centralManager.start().first(where: { $0 == .poweredOn })
print("Powered On, ready to scan")

let peripheral = try await centralManager.scanForPeripherals(withServices: nil).first()
```

Connecting

```swift
for await connectionState in await centralManager.connect(peripheral) {
  print(connectionState)
}

// or 

await centralManager.connect(peripheral)
for await connectionState in centralManager.connectionState(forPeripheral: peripheral) {
  print(connectionState)
}
```

Disconnecting

```swift 
for await connectionState in await centralManager.cancelPeripheralConnection(peripheral) {
  print(connectionState)
}

// or 

await centralManager.cancelPeripheralConnection(peripheral)
for await connectionState in centralManager.connectionState(forPeripheral: peripheral) {
  print(connectionState)
}
```

you can requst a new async stream or break out of these streams as much as you like without interfering with the peripheral connection. Once you call connect, the connection will be managed as normal by core bluetooth. You can call `cancelPeripheralConnection` at any time to cancel the connection. 

* Do not call `connect` when you're already connected
* Do not call `cancelPeripheralConnection` when you're not connected

SwiftUI:

```swift
struct PeripheralView: View {
  @ObservedObject var centralManager: CentralManager
  @ObservedObject var peripheral: Peripheral
  @State var connectButtonDisabled = false
  @State var disconnectButtonDisabled = true

  private func connect() async {
    do {
      for await connectionState in try await centralManager.connect(peripheral) {
        switch connectionState {
        case .connected, .connecting:
          connectButtonDisabled = true
          disconnectButtonDisabled = false
        case .disconnecting, .disconnected:
          connectButtonDisabled = false
          disconnectButtonDisabled = true
        case .failedToConnect:
          disconnectButtonDisabled = false
          connectButtonDisabled = false
        }
      }
    } catch {
      // happens when the device is already connected or connecting
      print("error trying to connect \(error)")
    }
  }

  private func disconnect() async {
    do {
      // optionally you can use thereturned state stream here to get connection state updates
      // but we're ignoring it here because we already get those updates from connect()
      try await centralManager.cancelPeripheralConnection(peripheral)
    } catch {
      // happens when the device is already disconnected
      print("error canceling connection\(error)")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("\(peripheral.name ?? "No Name")")

      Button("Connect") {
        Task {
          await connect()
        }
      }.disabled(connectButtonDisabled)

      Button("Disconnect") {
        Task {
          await disconnect()
        }
      }.disabled(disconnectButtonDisabled)

      switch peripheral.connectionState {
      case .connecting:
        Text("Connecting ")
      case .disconnected(let error):
        if let error = error {
          Text("Disconnected \(error.localizedDescription)")
        }
      case .connected:
        Text("Connected")
      case .disconnecting:
        Text("Disconnecting")
      case .failedToConnect(let error):
        Text("Failed to connect \(error.localizedDescription)")
      }
    }
  }
}
```