@preconcurrency
import CoreBluetoothMock
import Foundation

// CBMCentralManagerDelegate
extension CentralManager {
  func centralManagerDidUpdateState(_ central: CBMCentralManager) async {
    await MainActor.run {
      centralManagerState.bleState = central.state
    }
    stateContinuations.values.forEach { $0.yield(central.state) }
  }

  func centralManager(_ central: CBMCentralManager, willRestoreState dict: [String: Any]) {
    print("centralManager \(central) willRestoreState \(dict). Not yet implemented.")
  }

  func centralManager(_: CBMCentralManager, didDiscover cbPeripheral: CBMPeripheral, advertisementData _: [String: Any], rssi _: NSNumber) async {
    guard let scanForPeripheralsContinuation = scanForPeripheralsContinuation else {
      return
    }
    let p = await Peripheral.getOrCreatePeripheral(cbPeripheral: cbPeripheral)
    scanForPeripheralsContinuation.yield(p)
  }

  func centralManager(_: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) async {
    print(cbPeripheral.identifier, "didConnect")
    let state: Peripheral.ConnectionState = .connected
    await updatePeripheralConnectionState(peripheralUUID: cbPeripheral.identifier, state: state)
  }

  func centralManager(_: CBMCentralManager, didFailToConnect cbPeripheral: CBMPeripheral, error: Error?) async {
    print(cbPeripheral.identifier, "didFailToConnect", error ?? "")
    let error = error as? CBMError ?? CBMError(.unknown)
    let state: Peripheral.ConnectionState = .failedToConnect(error)
    await updatePeripheralConnectionState(peripheralUUID: cbPeripheral.identifier, state: state)
  }

  func centralManager(_: CBMCentralManager, didDisconnectPeripheral cbPeripheral: CBMPeripheral, error: Error?) async {
    print(cbPeripheral.identifier, "didDisconnectPeripheral", error ?? "")
    let error = error as? CBMError
    let state: Peripheral.ConnectionState = .disconnected(error)
    await updatePeripheralConnectionState(peripheralUUID: cbPeripheral.identifier, state: state)
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for cbPeripheral: CBMPeripheral) async {
    print("centralManager \(central) connectionEventDidOccur \(event) for \(cbPeripheral). Not yet implemented.")
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor cbPeripheral: CBMPeripheral) {
    print("centralManager \(central) didUpdateANCSAuthorizationFor \(cbPeripheral). Not yet implemented.")
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
    print("centralManager \(central) didDisconnectPeripheral \(peripheral) timestamp \(timestamp) isReconnecting \(isReconnecting) error \(String(describing: error)). Not yet implemented.")
  }
}

class CentralManagerDelegate: NSObject, CBMCentralManagerDelegate {
  let centralManager: CentralManager
  init(centralManager: CentralManager) {
    self.centralManager = centralManager
  }

  func centralManagerDidUpdateState(_ central: CBMCentralManager) {
    Task {
      await centralManager.centralManagerDidUpdateState(central)
      await centralManager.delegate?.centralManagerDidUpdateState(central)
    }
  }

  func centralManager(_ central: CBMCentralManager, willRestoreState dict: [String: Any]) {
    Task {
      await centralManager.centralManager(central, willRestoreState: dict)
      await centralManager.delegate?.centralManager(central, willRestoreState: dict)
    }
  }

  func centralManager(_ central: CBMCentralManager, didDiscover cbPeripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    Task {
      await centralManager.centralManager(central, didDiscover: cbPeripheral, advertisementData: advertisementData, rssi: RSSI)
      await centralManager.delegate?.centralManager(central, didDiscover: cbPeripheral, advertisementData: advertisementData, rssi: RSSI)
    }
  }

  func centralManager(_ central: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) {
    Task {
      await centralManager.centralManager(central, didConnect: cbPeripheral)
      await centralManager.delegate?.centralManager(central, didConnect: cbPeripheral)
    }
  }

  func centralManager(_ central: CBMCentralManager, didFailToConnect cbPeripheral: CBMPeripheral, error: Error?) {
    Task {
      await centralManager.centralManager(central, didFailToConnect: cbPeripheral, error: error)
      await centralManager.delegate?.centralManager(central, didFailToConnect: cbPeripheral, error: error)
    }
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral cbPeripheral: CBMPeripheral, error: Error?) {
    Task {
      await centralManager.centralManager(central, didDisconnectPeripheral: cbPeripheral, error: error)
      await centralManager.delegate?.centralManager(central, didDisconnectPeripheral: cbPeripheral, error: error)
    }
  }

  func centralManager(_ central: CBMCentralManager, connectionEventDidOccur event: CBMConnectionEvent, for cbPeripheral: CBMPeripheral) {
    Task {
      await centralManager.centralManager(central, connectionEventDidOccur: event, for: cbPeripheral)
      await centralManager.delegate?.centralManager(central, connectionEventDidOccur: event, for: cbPeripheral)
    }
  }

  func centralManager(_ central: CBMCentralManager, didUpdateANCSAuthorizationFor cbPeripheral: CBMPeripheral) {
    Task {
      await centralManager.centralManager(central, didUpdateANCSAuthorizationFor: cbPeripheral)
      await centralManager.delegate?.centralManager(central, didUpdateANCSAuthorizationFor: cbPeripheral)
    }
  }

  func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
    Task {
      await centralManager.centralManager(central, didDisconnectPeripheral: peripheral, timestamp: timestamp, isReconnecting: isReconnecting, error: error)
      await centralManager.delegate?.centralManager(central, didDisconnectPeripheral: peripheral, timestamp: timestamp, isReconnecting: isReconnecting, error: error)
    }
  }
}
