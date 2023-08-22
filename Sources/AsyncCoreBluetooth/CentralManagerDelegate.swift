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

  func centralManager(_: CBMCentralManager, didDiscover cbPeripheral: CBMPeripheral, advertisementData _: [String: Any], rssi _: NSNumber) {
    // print("centralManager \(central) didDiscover \(cbPeripheral) advertisementData \(advertisementData) rssi \(RSSI)")
    guard let scanForPeripheralsContinuation = scanForPeripheralsContinuation else {
      return
    }
    let p = Peripheral(cbPeripheral: cbPeripheral)
    scanForPeripheralsContinuation.yield(p)
  }

  func centralManager(_: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) async {
    // print("centralManager \(central) didConnect \(cbPeripheral)")
    let state: Peripheral.ConnectionState = .connected
    let peripheralConnectionContinuations = getPeripheralConnectionContinuations(peripheralUUID: cbPeripheral.identifier)
    for peripheralConnectionContinuation in peripheralConnectionContinuations {
      await peripheralConnectionContinuation.peripheral.setConnectionState(state)
      peripheralConnectionContinuation.continuation.yield(state)
    }
  }

  func centralManager(_ central: CBMCentralManager, didFailToConnect cbPeripheral: CBMPeripheral, error: Error?) async {
    // print("centralManager \(central) didFailToConnect \(cbPeripheral) error \(String(describing: error))")

    let error = error as? CBMError ?? CBMError(.unknown)
    let state: Peripheral.ConnectionState = .failedToConnect(error)
    let peripheralConnectionContinuations = getPeripheralConnectionContinuations(peripheralUUID: cbPeripheral.identifier)
    for peripheralConnectionContinuation in peripheralConnectionContinuations {
      await peripheralConnectionContinuation.peripheral.setConnectionState(state)
      peripheralConnectionContinuation.continuation.yield(state)
    }
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral cbPeripheral: CBMPeripheral, error: Error?) async {
    print("centralManager \(central) didDisconnectPeripheral \(cbPeripheral) error \(String(describing: error))")
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for cbPeripheral: CBMPeripheral) async {
    print("centralManager \(central) connectionEventDidOccur \(event) for \(cbPeripheral)")
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor cbPeripheral: CBMPeripheral) {
    print("centralManager \(central) didUpdateANCSAuthorizationFor \(cbPeripheral)")
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

  func centralManager(_ central: CBMCentralManager, didDiscover cbPeripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    Task { await centralManager.centralManager(central, didDiscover: cbPeripheral, advertisementData: advertisementData, rssi: RSSI) }
    centralManager.delegate?.centralManager(central, didDiscover: cbPeripheral, advertisementData: advertisementData, rssi: RSSI)
  }

  func centralManager(_ central: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, didConnect: cbPeripheral) }
    centralManager.delegate?.centralManager(central, didConnect: cbPeripheral)
  }

  func centralManager(_ central: CBMCentralManager, didFailToConnect cbPeripheral: CBMPeripheral, error: Error?) {
    Task { await centralManager.centralManager(central, didFailToConnect: cbPeripheral, error: error) }
    centralManager.delegate?.centralManager(central, didFailToConnect: cbPeripheral, error: error)
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral cbPeripheral: CBMPeripheral, error: Error?) {
    Task { await centralManager.centralManager(central, didDisconnectPeripheral: cbPeripheral, error: error) }
    centralManager.delegate?.centralManager(central, didDisconnectPeripheral: cbPeripheral, error: error)
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for cbPeripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, connectionEventDidOccur: event, for: cbPeripheral) }
    centralManager.delegate?.centralManager(central, connectionEventDidOccur: event, for: cbPeripheral)
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor cbPeripheral: CBMPeripheral) {
    Task { await centralManager.centralManager(central, didUpdateANCSAuthorizationFor: cbPeripheral) }
    centralManager.delegate?.centralManager(central, didUpdateANCSAuthorizationFor: cbPeripheral)
  }
}
