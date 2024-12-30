# Example No UI

An example of using this library to connect to a peripheral and manage the service and characterisitc connections without regarding UI. 

The UI components can be plugged in however you like, this will just manage auto connecting and maintaining the connection.

```swift
//
//  BLEManager.swift
//  Eye Camera UIKit
//
//  Created by Sam Meech-Ward on 2024-12-29.
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation
import MightFail

let SERVICE_UUID = CBUUID(string: "5C1B9A0D-B5BE-4A40-8F7A-66B36D0A5176")
let READ_CHAR_UUID = CBUUID(string: "5C1B9A0D-B5BE-4A40-8F7A-66B36D0A5177")
let WRITE_CHAR_UUID = CBUUID(string: "5C1B9A0D-B5BE-4A40-8F7A-66B36D0A5178")
let NOTIFY_CHAR_UUID = CBUUID(string: "5C1B9A0D-B5BE-4A40-8F7A-66B36D0A5179")

enum BLEStorage {
  private static let deviceUUIDsKey = "deviceUUIDs"

  static func saveDevice(uuid: UUID) {
    var savedUUIDs = getSavedDevices()
    guard !savedUUIDs.contains(uuid) else {
      return
    }
    savedUUIDs.append(uuid)
    let uuidStrings = savedUUIDs.map { $0.uuidString }
    UserDefaults.standard.set(uuidStrings, forKey: deviceUUIDsKey)
  }

  static func getSavedDevices() -> [UUID] {
    if let uuidStrings = UserDefaults.standard.array(forKey: deviceUUIDsKey) as? [String] {
      return uuidStrings.compactMap { UUID(uuidString: $0) }
    }
    return []
  }
}

actor BLEManager {
  let central = CentralManager()
  var peripheral: Peripheral?
  var myService: Service?
  var readCharacteristic: Characteristic?
  var writeCharacteristic: Characteristic?
  var notifyCharacteristic: Characteristic?

  static let shared = BLEManager()
  private var task: Task<Void, Never>?
  private init() {}

  func scanAndConnect() {
    task = Task {
      for await bleState in await central.startStream() {
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
          await connnect()
        }
      }
    }
  }

  private func connnect() async {
    guard let peripheral = await getPeripheral() else {
      print("couldn't find peripheral")
      return
    }
    self.peripheral = peripheral
    let (error, connectionState) = await mightFail { try await central.connect(peripheral, options: [CBConnectPeripheralOptionEnableAutoReconnect: true]) }

    guard let connectionState else {
      print("Error connecting: \(error.localizedDescription)")
      return
    }

    for await state in connectionState {
      switch state {
      case .disconnected(let error):
        if let error = error {
          print("Disconnected with error: \(error)")
        } else {
          print("Disconnected normally")
        }

      case .connecting:
        print("Connecting to peripheral...")

      case .disconnecting:
        print("Disconnecting from peripheral...")

      case .failedToConnect(let error):
        print("Failed to connect: \(error)")

      case .connected:
        print("Connected successfully")
        await getSevices(peripheral: peripheral)
      }
    }
  }

  private func getPeripheral() async -> Peripheral? {
    let savedUUIDs = BLEStorage.getSavedDevices()
    if savedUUIDs.count > 0 {
      let savedPeripherals = await central.retrievePeripherals(withIdentifiers: savedUUIDs)
      return savedPeripherals.first
    }
    let (error, peripheral) = await mightFail { try await central.scanForPeripherals(withServices: [SERVICE_UUID]).first(where: { _ in true }) }
    guard let peripheral else {
      print("Error scanning: \(error.localizedDescription)")
      return nil
    }
    if let identifier = await peripheral?.identifier {
      BLEStorage.saveDevice(uuid: identifier)
    }

    return peripheral
  }

  private func getSevices(peripheral: Peripheral) async {
    let (servicesError, services) = await mightFail { try await peripheral.discoverServices([SERVICE_UUID]) }
    guard let services else {
      print("error discovering services \(servicesError)")
      return
    }
    guard let service = services[SERVICE_UUID] else {
      print("service with uuid \(SERVICE_UUID) not found")
      return
    }
    myService = service
    let (characteristicsError, characteristics) = await mightFail { try await peripheral.discoverCharacteristics([READ_CHAR_UUID, WRITE_CHAR_UUID, NOTIFY_CHAR_UUID], for: service) }
    guard let characteristics else {
      print("error discovering characteristics \(characteristicsError)")
      return
    }

    readCharacteristic = characteristics[READ_CHAR_UUID]
    writeCharacteristic = characteristics[WRITE_CHAR_UUID]
    notifyCharacteristic = characteristics[NOTIFY_CHAR_UUID]
  }
}
```