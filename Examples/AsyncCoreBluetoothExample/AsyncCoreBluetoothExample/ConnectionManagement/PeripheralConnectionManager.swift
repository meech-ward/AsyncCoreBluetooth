//
//  PeripheralConnectionManager.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation
import MightFail

@MainActor
@Observable
final class PeripheralConnectionManager {
  @ObservationIgnored
  private let central: CentralManager
  init(central: CentralManager) {
    self.central = central
  }

  var peripheral: Peripheral?
  var heartRateService: Service?
  var heartRateMeasurementCharacteristic: Characteristic?
  var automationIOService: Service?
  var ledControlCharacteristic: Characteristic?
  var error: Error?

  @ObservationIgnored
  private var connectTask: Task<Void, Never>?

  private func resetObjects() {
    heartRateService = nil
    heartRateMeasurementCharacteristic = nil
    automationIOService = nil
    ledControlCharacteristic = nil
    error = nil
  }

  func stop() async {
    if let peripheral = peripheral {
      for await state in await central.cancelPeripheralConnection(peripheral) {
        if case .disconnected = state {
          break
        }
      }
    }

    connectTask?.cancel()
    connectTask = nil
    resetObjects()
  }

  func manageConnection(peripheralUUID string: String?) async {
    guard let string, let uuid = UUID(uuidString: string) else {
      await stop()
      return
    }
    let peripheral = await central.retrievePeripheral(withIdentifier: uuid)
    self.peripheral = peripheral
    guard let peripheral else { return }

    await manageConnection(peripheral: peripheral)
  }

  private func manageConnection(peripheral: Peripheral) async {
    await stop()
    connectTask = Task {
      for await state in await self.central.connect(peripheral) {
        // this is also where auto retry logic can happen
        // if it goes into a disconnected or error state, .connect needs to be called again
        // so you could infinitely loop this with some checks and backoffs to always attempt reconnection
        print("state: \(state)")
        if Task.isCancelled {
          break
        }

        guard state == .connected else {
          resetObjects()
          continue
        }

        let (error, _, success) = await mightFail { try await self.discoverServicesAndCharacteristics(peripheral: peripheral) }
        guard success else {
          self.error = error
          break
        }
      }
    }
  }

  private func discoverServicesAndCharacteristics(peripheral: Peripheral) async throws {
    let heartRateService = try await peripheral.discoverService(BLEIdentifiers.Service.heartRate)
    let heartRateMeasurementCharacteristic = try await peripheral.discoverCharacteristic(BLEIdentifiers.Characteristic.heartRateMeasurement, for: heartRateService)
    let automationIOService = try await peripheral.discoverService(BLEIdentifiers.Service.automationIO)
    let ledControlCharacteristic = try await peripheral.discoverCharacteristic(BLEIdentifiers.Characteristic.ledControl, for: automationIOService)
    self.heartRateService = heartRateService
    self.heartRateMeasurementCharacteristic = heartRateMeasurementCharacteristic
    self.automationIOService = automationIOService
    self.ledControlCharacteristic = ledControlCharacteristic
  }
}
