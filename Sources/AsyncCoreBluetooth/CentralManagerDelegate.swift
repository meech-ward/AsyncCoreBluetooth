@preconcurrency
import CoreBluetoothMock
import Foundation

// CBMCentralManagerDelegate
extension CentralManager {
  func centralManagerDidUpdateState(_ central: CBMCentralManager) async {
    bleState = central.state
    stateContinuations.values.forEach { $0.yield(bleState) }

    delegate?.centralManagerDidUpdateState(central)
  }

  func centralManager(_ central: CBMCentralManager, willRestoreState dict: [String: Any]) {
    print("centralManager \(central) willRestoreState \(dict). Not yet implemented.")
  }

  func centralManager(_ central: CBMCentralManager, didDiscover peripheralWrapper: PeripheralWrapper, advertisementData: [AdvertisementDataValue], rssi RSSI: NSNumber) async {
    let cbPeripheral = peripheralWrapper.peripheral
    let originalFormatAdvertisementData: [String: Any] = Dictionary(
      uniqueKeysWithValues: advertisementData.map { ($0.key, $0.originalValue) }
    )
    delegate?.centralManager(central, didDiscover: cbPeripheral, advertisementData: originalFormatAdvertisementData, rssi: RSSI)
    guard let scanForPeripheralsContinuation = scanForPeripheralsContinuation else {
      return
    }
    let p = await Peripheral.getOrCreatePeripheral(cbPeripheral: cbPeripheral)
    scanForPeripheralsContinuation.yield(p)
  }

  func centralManager(_ central: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) async {
    delegate?.centralManager(central, didConnect: cbPeripheral)
    print(cbPeripheral.identifier, "didConnect")
    let state: PeripheralConnectionState = .connected
    await updatePeripheralConnectionState(peripheralUUID: cbPeripheral.identifier, state: state)
  }

  func centralManager(_: CBMCentralManager, didFailToConnect cbPeripheral: CBMPeripheral, error: Error?) async {
    print(cbPeripheral.identifier, "didFailToConnect", error ?? "")
    let error = error as? CBMError ?? CBMError(.unknown)
    let state: PeripheralConnectionState = .failedToConnect(error)
    await updatePeripheralConnectionState(peripheralUUID: cbPeripheral.identifier, state: state)
  }

  func centralManager(_: CBMCentralManager, didDisconnectPeripheral cbPeripheral: CBMPeripheral, error: Error?) async {
    print(cbPeripheral.identifier, "didDisconnectPeripheral", error ?? "")
    let error = error as? CBMError
    let state: PeripheralConnectionState = .disconnected(error)
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

class CentralManagerDelegate: NSObject, CBMCentralManagerDelegate, @unchecked Sendable {
  let centralManager: CentralManager
  init(centralManager: CentralManager) {
    self.centralManager = centralManager
  }

  func centralManagerDidUpdateState(_ central: CBMCentralManager) {
    Task {
      await centralManager.centralManagerDidUpdateState(central)
    }
  }

  func centralManager(_: CBMCentralManager, willRestoreState dict: [String: Any]) {
    print(dict)
//    Task {
//      let d = dict
//      await centralManager.centralManager(central, willRestoreState: d)
//      await centralManager.delegate?.centralManager(central, willRestoreState: d)
//    }
  }

  private func parseAdvertisementData(_ advertisementData: [String: Any]) -> [AdvertisementDataValue] {
    return advertisementData.compactMap { value in
      AdvertisementDataValue(key: value.key, value: value.value)
    }
  }

  func centralManager(_ central: CBMCentralManager, didDiscover cbPeripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    let adData = parseAdvertisementData(advertisementData)
    let wrapper = PeripheralWrapper(peripheral: cbPeripheral)
    Task {
      await centralManager.centralManager(central, didDiscover: wrapper, advertisementData: adData, rssi: RSSI)
    }
  }

  func centralManager(_ central: CBMCentralManager, didConnect cbPeripheral: CBMPeripheral) {
    Task {
      await centralManager.centralManager(central, didConnect: cbPeripheral)
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
