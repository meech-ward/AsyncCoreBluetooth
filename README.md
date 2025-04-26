# Async Core Bluetooth

![Build and Test](https://github.com/meech-ward/AsyncCoreBluetooth/actions/workflows/build.yml/badge.svg)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmeech-ward%2FAsyncCoreBluetooth%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/meech-ward/AsyncCoreBluetooth)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmeech-ward%2FAsyncCoreBluetooth%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/meech-ward/AsyncCoreBluetooth)

This library is a Swift 6 wrapper around [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) and [CoreBluetoothMock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) that allows you to write your core bluetooth code using swift concurrency. It also plays nice with SwiftUI.

The main classes are:

- `CentralManager` which wraps `CBCentralManager` and `CBMCentralManager`. It's very similiar to `CBCentralManager` but it's methods are all `async` and it provides a state property`@Observable` properties.
- `Peripheral` which wraps `CBPeripheral` and `CBMPeripheral`. It's very similiar to `CBPeripheral` but it's methods are all `async` and it provides a state property with `@Observable` properties.

If you know the CoreBluetooth API you should be able to use this library without any issues.

## Limitations

This library only supports the central role, it does not support the peripheral role. That means you can only use this library to scan for and connect to peripherals, you cannot use it to advertise or act as a peripheral. That feature may be added in the future, but is not a high priority since using an apple device as a peripheral device is not very common.

It's also in the early stages of development, so here are things that are not yet implemented:

- write for descriptors (write for characteristics is supported)
- read for descriptors (read for characteristics is supported)
- `centralManager(_: CBMCentralManager, willRestoreState dict: [String: Any])`
- `centralManager(_: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for cbPeripheral: CBMPeripheral)`
- `centralManager(_: CBMCentralManager, didUpdateANCSAuthorizationFor cbPeripheral: CBMPeripheral)`
- `centralManager(_: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?)`
- `peripheral(_: CBMPeripheral, didModifyServices invalidatedServices: [CBMService])`
- `peripheral(_: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?)`
- `peripheral(_: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?)`
- `peripheral(_: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic, error: Error?)`
- `peripheral(_: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?)`
- `peripheral(_: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?)`

so the bare minimum is working fine, but the rest is still to come.

## Core Bluetooth

* https://developer.apple.com/documentation/corebluetooth
* https://punchthrough.com/core-bluetooth-basics/

## Swift Package Manager

Add AsyncCoreBluetooth as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/meech-ward/AsyncCoreBluetooth.git", from: "0.1.0")
]
```

Then add it to your target's dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AsyncCoreBluetooth"]),
]
```

## Examples

Documentation is a little lacking right now. Check the Examples in the examples folder for more complete examples.

Here are some snippets:

## AsyncObservable

This library uses the [AsyncObservable](https://github.com/meech-ward/AsyncObservable) library to provide observable properties. 

This means that properties that might change over time can easily be observed. For example:

```swift
// the current connection state of the peripheral (.connected, .disconnected, .connecting, .disconnecting, .failedToConnect)
peripheral.connectionState.current 

// the connection state observed over time as an AsyncStream
for await state in peripheral.connectionState.stream { 
  //...
}

// the connection state observed over time as an @Observable
// so you can use it in SwiftUI
switch peripheral.connectionState.observable {
  case .disconnected:
    Text("disconnected")
  //...
}
```

So you'll see `.current`, `.stream`, and `.observable` a lot.

## Initializing The Central Manager

Setup the central manager and check the current ble state by calling `start()` or `startStream()`. They do the same thing, but `startStream()` returns an `AsyncStream` that you can use to listen for changes to the ble state.

```swift
import AsyncCoreBluetooth

let centralManager = CentralManager()

for await bleState in await centralManager.start() {
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

The current state stream is always available as an `AsyncObservable` through `.bleState`

```swift
// async stream
for await bleState in await centralManager.bleState.stream {
  //...
}
```

Or `.observable` to make it easy to use with SwiftUI:

```swift
import AsyncCoreBluetooth

struct ContentView: View {
  var centralManager = CentralManager()
  var body: some View {
    NavigationStack {
      VStack {
        switch centralManager.bleState.observable {
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
      // or startStream if you want the async stream returned from start
    }
  }
}
```

Your application should handle all the possible cases of the ble state. It's very common for someone to turn off bluetooth or turn on airplane mode and your application's UI should reflect these states. However, the most common case is `.poweredOn`, so if you're only interested in running code as soon as the device is in that state, you can use the following:

```swift
for await _ in await centralManager.startStream().first(where: {$0 == .poweredOn}) {
  // re run the setup code if it goes off then back on
}
```

Keep in mind that familiarity with swift concurrency is going to make using this library a lot easier.

### Scanning or Stopping Scans of Peripherals

```swift
import AsyncCoreBluetooth

let heartRateServiceUUID = UUID(string: "180D")

do {
  let peripherals = try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID])
  let peripheral = peripherals[heartRateServiceUUID]
  print("found peripheral \(peripheral)")
} catch {
  // This only happens when ble state is not powered on or you're already scanning
  print("error scanning for peripherals \(error)")
}
```

SwiftUI:

```swift
struct ScanningPeripherals: View {
  @State private var peripherals: [Peripheral] = []

  var body: some View {
    VStack {
      List(peripherals, id: \.identifier) { peripheral in
        Section {
          ScannedPeripheralRow(centralManager: centralManager, peripheral: peripheral)
        }
      }
    }
    .task {
      do {
        // the scan wil stop when this loop is terminated or the task is cancelled
        // so when this view is dismissed the scan will stop
        for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: [heartRateServiceUUID]) {
          peripherals.append(peripheral)
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

Or use the `centralManager.peripheralsScanned` `AsyncObservable` to observe the peripherals that have been scanned:

```swift
struct ScanningPeripherals: View {

  var body: some View {
    VStack {
      List(centralManager.peripheralsScanned.observable, id: \.identifier) { peripheral in
        Section {
          ScannedPeripheralRow(centralManager: centralManager, peripheral: peripheral)
        }
      }
    }
    .task {
      do {
        // you need to manually stop the scan when you're done
        try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID]) {
      } catch {
        // This only happens when ble state is not powered on or you're already scanning
        print("error scanning for peripherals \(error)")
      }
    }
    .onDisappear {
      // you need to manually stop the scan when you're done
      Task { await centralManager.stopScan() }
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

- Defaults to `disconnected(nil)`
- Calling `connect()` on the central manager will cause the connectionState to change to connecting
- After conencting, the device will change to connected or `failedToConnect()`
- Calling `disconnect()` on the central manager will cause the connectionState to change to `disconnecting`
- After `disconnecting`, the device will change to `disconnected(nil)`
- If the device disconnects unexpectedly, the device will change straight from connected to `disconnected(error)`


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
for await connectionState in peripheral.connectionState.stream {
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
for await connectionState in peripheral.connectionState.stream {
  print(connectionState)
}
```

you can requst a new async stream or break out of these streams as much as you like without interfering with the peripheral connection. Once you call connect, the connection will be managed as normal by core bluetooth. 

You can call `cancelPeripheralConnection` at any time to cancel the connection.

## Read

```swift
let data = try await peripheral.readValue(for: characteristic)
```

The characteristic's value is also available on the characteristic's `AsyncObservable` `.value` property:

```swift
let data = characteristic.value.current // or .stream or .observable
```

But you **MUST** either read `peripheral.readValue` or `peripheral.setNotifyValue(true` for this value to have any data. Reading it will **NOT** trigger a read from the peripheral device.

## Notifications

```swift
try await peripheral.setNotifyValue(true, for: characteristic)
//...
for await value in characteristic.value.stream { // or .current or .observable
  //...
}
```

## Write

```swift
try await peripheral.writeValueWithResponse(data, for: characteristic) 
```

## RSSI

You can read the Received Signal Strength Indicator (RSSI) of a peripheral to determine its signal strength:

```swift
// Read RSSI once
let rssiValue = try await peripheral.readRSSI()
print("Signal strength: \(rssiValue) dBm") // Values typically range from -40 (near) to -100 dBm (far)

// Or observe RSSI changes over time
for await rssi in peripheral.rssi.stream {
  print("RSSI updated: \(rssi) dBm") 
  if rssi > -50 {
    print("Device is very close")
  } else if rssi > -70 {
    print("Device is at medium range")
  } else {
    print("Device is far away")
  }
}

// note that the rssi is only updated when you call readRSSI, so you would need to call this for the loop to itterate
```

## Running Tests

```
swift test --no-parallel
```

## Building Documentation

check build.sh