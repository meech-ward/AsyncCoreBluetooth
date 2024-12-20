import CoreBluetooth
import CoreBluetoothMock

/// See CoreBluetoothMock.CBMManagerTypes
public typealias CentralManagerBLEState = CBMManagerState

public typealias PeripheralBLEState = CBMPeripheralState

public typealias Service = CBMService
public typealias Characteristic = CBMCharacteristic
public typealias Descriptor = CBMDescriptor

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
