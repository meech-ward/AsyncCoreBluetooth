import CoreBluetoothMock
import Foundation

// CBMCentralManagerDelegate
extension CentralManager {
  func centralManagerDidUpdateState(_ central: CBMCentralManager) async {
//    print("centralManagerDidUpdateState \(central)")
    await MainActor.run {
      bleState = central.state
    }
    stateContinuations.values.forEach { $0.yield(central.state) }
  }

  func centralManager(_ central: CBMCentralManager, willRestoreState dict: [String: Any]) {
    print("centralManager \(central) willRestoreState \(dict)")
  }

  func centralManager(_ central: CBMCentralManager, didDiscover peripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    print("centralManager \(central) didDiscover \(peripheral) advertisementData \(advertisementData) rssi \(RSSI)")
    guard let scanForPeripheralsContinuation = scanForPeripheralsContinuation else {
      return
    }
    scanForPeripheralsContinuation.yield(peripheral)
  }

  func centralManager(_ central: CBMCentralManager, didConnect peripheral: CBMPeripheral) async {
    print("centralManager \(central) didConnect \(peripheral)")
  }

  func centralManager(_ central: CBMCentralManager, didFailToConnect peripheral: CBMPeripheral, error: Error?) async {
    print("centralManager \(central) didFailToConnect \(peripheral) error \(String(describing: error))")
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, error: Error?) async {
    print("centralManager \(central) didDisconnectPeripheral \(peripheral) error \(String(describing: error))")
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for peripheral: CBMPeripheral) async {
    print("centralManager \(central) connectionEventDidOccur \(event) for \(peripheral)")
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor peripheral: CBMPeripheral) {
    print("centralManager \(central) didUpdateANCSAuthorizationFor \(peripheral)")
  }
}

class CentralManagerDelegate: NSObject, CBMCentralManagerDelegate {
  let centralManager: CentralManager
  init(centralManager: CentralManager) {
    self.centralManager = centralManager
  }

  func centralManagerDidUpdateState(_ central: CBMCentralManager) {
    Task { await centralManager.centralManagerDidUpdateState(central) }
    centralManager.delegate?.centralManagerDidUpdateState(central)
  }

  func centralManager(_ central: CBMCentralManager, willRestoreState dict: [String: Any]) {
    Task { await centralManager.centralManager(central, willRestoreState: dict) }
    centralManager.delegate?.centralManager(central, willRestoreState: dict)
  }

  func centralManager(_ central: CBMCentralManager, didDiscover peripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    Task { await centralManager.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI) }
    centralManager.delegate?.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
  }

  func centralManager(_ central: CBMCentralManager, didConnect peripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, didConnect: peripheral) }
    centralManager.delegate?.centralManager(central, didConnect: peripheral)
  }

  func centralManager(_ central: CBMCentralManager, didFailToConnect peripheral: CBMPeripheral, error: Error?) {
    Task { await centralManager.centralManager(central, didFailToConnect: peripheral, error: error) }
    centralManager.delegate?.centralManager(central, didFailToConnect: peripheral, error: error)
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, error: Error?) {
    Task { await centralManager.centralManager(central, didDisconnectPeripheral: peripheral, error: error) }
    centralManager.delegate?.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for peripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, connectionEventDidOccur: event, for: peripheral) }
    centralManager.delegate?.centralManager(central, connectionEventDidOccur: event, for: peripheral)
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor peripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, didUpdateANCSAuthorizationFor: peripheral) }
    centralManager.delegate?.centralManager(central, didUpdateANCSAuthorizationFor: peripheral)
  }
}
