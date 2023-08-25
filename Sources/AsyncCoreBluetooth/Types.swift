import CoreBluetooth
import CoreBluetoothMock

/// See CoreBluetoothMock.CBMManagerTypes
public typealias CentralManagerState = CBMManagerState

public typealias PeripheralState = CBMPeripheralState

public enum CentralManagerError: Error {
  case alreadyScanning
  case notPoweredOn
}

public enum PeripheralConnectionError: Error {
  case alreadyConnecting
  case alreadyConnected
  case alreadyDisconnecting
  case alreadyDisconnected
  case failedToConnect
}
