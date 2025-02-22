import CoreBluetooth
import CoreBluetoothMock

extension CBMCentralManager: @retroactive @unchecked Sendable {}
// extension CBMPeripheral: @retroactive @unchecked Sendable {}
extension CBMCharacteristic: @retroactive @unchecked Sendable {}
extension CBMService: @retroactive @unchecked Sendable {}
extension CBMUUID: @retroactive @unchecked Sendable {}
extension CBML2CAPChannel: @retroactive @unchecked Sendable {}
extension CBMManagerState: @retroactive @unchecked Sendable {}
class PeripheralWrapper: @unchecked Sendable {
  var peripheral: CBMPeripheral
  init(peripheral: CBMPeripheral) {
    self.peripheral = peripheral
  }
}

/// See CoreBluetoothMock.CBMManagerTypes
public typealias CentralManagerBLEState = CBMManagerState

public typealias PeripheralBLEState = CBMPeripheralState

// public class Service: CBMService, Identifiable, Sendable {
//   public let identifier: UUID
// }
public typealias Descriptor = CBMDescriptor

public enum AsyncCoreBluetoothError: Error {
  case taskCancelled
  case unexpectedNilData
}

public enum CentralManagerError: Error {
  case alreadyScanning
  case notPoweredOn
}

public enum PeripheralConnectionError: String, Error {
  case alreadyConnecting
  case alreadyConnected
  case alreadyDisconnecting
  case alreadyDisconnected
  case failedToConnect
}

public enum ServiceError: Error {
  case unableToFindServices
}

public enum CharacteristicError: Error {
  case unableToFindCharacteristics
  case unableToFindCharacteristicService
}

public enum AdvertisementDataValue: Sendable {
  case localName(key: String, value: String)
  case manufacturerData(key: String, value: Data)
  case serviceData(key: String, value: [CBMUUID: Data])
  case serviceUUIDs(key: String, value: [CBMUUID])
  case overflowServiceUUIDs(key: String, value: [CBMUUID])
  case txPowerLevel(key: String, value: NSNumber)
  case isConnectable(key: String, value: NSNumber)
  case solicitedServiceUUIDs(key: String, value: [CBMUUID])

  init?(key: String, value: Any) {
    switch key {
    case CBMAdvertisementDataLocalNameKey:
      guard let value = value as? String else { return nil }
      self = .localName(key: key, value: value)

    case CBMAdvertisementDataManufacturerDataKey:
      guard let value = value as? Data else { return nil }
      self = .manufacturerData(key: key, value: value)

    case CBMAdvertisementDataServiceDataKey:
      guard let value = value as? [CBMUUID: Data] else { return nil }
      self = .serviceData(key: key, value: value)

    case CBMAdvertisementDataServiceUUIDsKey:
      guard let value = value as? [CBMUUID] else { return nil }
      self = .serviceUUIDs(key: key, value: value)

    case CBMAdvertisementDataOverflowServiceUUIDsKey:
      guard let value = value as? [CBMUUID] else { return nil }
      self = .overflowServiceUUIDs(key: key, value: value)

    case CBMAdvertisementDataTxPowerLevelKey:
      guard let value = value as? NSNumber else { return nil }
      self = .txPowerLevel(key: key, value: value)

    case CBMAdvertisementDataIsConnectable:
      guard let value = value as? NSNumber else { return nil }
      self = .isConnectable(key: key, value: value)

    case CBMAdvertisementDataSolicitedServiceUUIDsKey:
      guard let value = value as? [CBMUUID] else { return nil }
      self = .solicitedServiceUUIDs(key: key, value: value)

    default:
      return nil
    }
  }

  var originalValue: Any {
    switch self {
    case .localName(_, let value): return value
    case .manufacturerData(_, let value): return value
    case .serviceData(_, let value): return value
    case .serviceUUIDs(_, let value): return value
    case .overflowServiceUUIDs(_, let value): return value
    case .txPowerLevel(_, let value): return value
    case .isConnectable(_, let value): return value
    case .solicitedServiceUUIDs(_, let value): return value
    }
  }

  var key: String {
    switch self {
    case .localName(let key, _): return key
    case .manufacturerData(let key, _): return key
    case .serviceData(let key, _): return key
    case .serviceUUIDs(let key, _): return key
    case .overflowServiceUUIDs(let key, _): return key
    case .txPowerLevel(let key, _): return key
    case .isConnectable(let key, _): return key
    case .solicitedServiceUUIDs(let key, _): return key
    }
  }
}
