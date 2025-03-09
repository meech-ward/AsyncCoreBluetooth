//
//  BluetoothManager.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//

import AsyncCoreBluetooth
import AsyncObservable
import AsyncObservableUserDefaults
import CoreBluetooth
import Foundation

enum BLEIdentifiers {
  static let name = "NimBLE_GATT"
  /// Service UUIDs
  enum Service {
    /// Heart Rate Service (0x180D)
    static let heartRate = CBUUID(string: "180D")

    /// Automation IO Service (0x1815)
    static let automationIO = CBUUID(string: "1815")
  }

  static let services: [CBUUID] = [
    Service.heartRate,
    Service.automationIO
  ]

  /// Characteristic UUIDs
  enum Characteristic {
    /// Heart Rate Measurement Characteristic (0x2A37)
    static let heartRateMeasurement = CBUUID(string: "2A37")

    /// LED Control Characteristic
    static let ledControl = CBUUID(string: "00001525-1212-EFDE-1523-785FEABCD123")
  }
}

actor PeripheralConnectionManager {
  enum PeripheralConnectionManagerState: Equatable {
    static func == (lhs: PeripheralConnectionManager.PeripheralConnectionManagerState, rhs: PeripheralConnectionManager.PeripheralConnectionManagerState) -> Bool {
      switch (lhs, rhs) {
        case (.notReady, .notReady): return true
        case (.ready, .ready): return true
        case (.error(_), .error(_)): return true
        default: return false
      }
    }

    case notReady
    case ready
    case error(Error)
  }

  let state: AsyncObservable<PeripheralConnectionManagerState> = .init(.notReady)

  let central: CentralManager
  init(central: CentralManager) {
    self.central = central
  }

  let peripheral: AsyncObservable<Peripheral?> = .init(nil)
  var connectTask: Task<Void, Never>?

  func stop() async {
    do {
      if let peripheral = peripheral.current {
        if await peripheral.connectionState == .connected {
          try await central.cancelPeripheralConnection(peripheral)
        }
      }
    } catch {
      state.update(.error(error))
    }

    connectTask?.cancel()
    connectTask = nil
    state.update(.notReady)
  }

  func manageConnection(peripheralUUID string: String?) async {
    guard let string, let uuid = UUID(uuidString: string) else {
      state.update(.notReady)
      return
    }
    let peripheral = await central.retrievePeripheral(withIdentifier: uuid)
    self.peripheral.update(peripheral)
    guard let peripheral else { return }

    await manageConnection(peripheral: peripheral)
  }

  func manageConnection(peripheral: Peripheral) async {
    await stop()
    connectTask = Task {
      for await state in await central.connect(peripheral) {
        // this is also where auto retry logic can happen

        guard state == .connected else {
          self.state.update(.notReady)
          continue
        }
        do {
          try await discoverServicesAndCharacteristics(peripheral: peripheral)
          self.state.update(.ready)
        } catch {
          self.state.update(.error(error))
        }
      }
    }
  }

  private func discoverServicesAndCharacteristics(peripheral: Peripheral) async throws {
    let heartRateService = try await peripheral.discoverService(BLEIdentifiers.Service.heartRate)
    try await peripheral.discoverCharacteristic(BLEIdentifiers.Characteristic.heartRateMeasurement, for: heartRateService)
    let automationIOService = try await peripheral.discoverService(BLEIdentifiers.Service.automationIO)
    try await peripheral.discoverCharacteristic(BLEIdentifiers.Characteristic.ledControl, for: automationIOService)
  }
}
