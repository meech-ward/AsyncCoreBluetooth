import Foundation
import CoreBluetooth
import AsyncCoreBluetooth


actor MyAppsBLEManager {
  let centralManager = CentralManager()
  var peripheral: Peripheral?

  func start() async {
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
  }

  func scanForPeripheral() async {
    let heartRateServiceUUID = CBUUID(string: "180D")

    do {
        let peripherals = try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID])
        let peripheral = peripherals[heartRateServiceUUID]
        print("found peripheral \(peripheral)")
    } catch {
        // This only happens when ble state is not powered on or you're already scanning
        print("error scanning for peripherals \(error)")
    }
  }
}
