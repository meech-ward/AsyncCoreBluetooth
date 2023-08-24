import CoreBluetooth
import CoreBluetoothMock
import Foundation

public actor Peripheral: ObservableObject {
  /// * Defaults to disconnected(nil)
  /// * Calling connect() on the central manager will cause the connectionState to change to connecting
  /// * After conencting, the device will change to connected or failedToConnect
  /// * Calling disconnect() on the central manager will cause the connectionState to change to disconnecting
  /// * After disconnecting, the device will change to disconnected(nil)
  /// * If the device disconnects unexpectedly, the device will change straight from connected to disconnected(error)
  public enum ConnectionState: Equatable {
    case disconnected(CBError?)
    case connecting
    case connected
    case disconnecting
    case failedToConnect(CBError)
  }

  public private(set) var cbPeripheral: CBMPeripheral

  @MainActor public let identifier: UUID
  @MainActor @Published public internal(set) var connectionState: ConnectionState = .disconnected(nil)
  @MainActor @Published public private(set) var name: String?

  var delegate: CBMPeripheralDelegate?

  // A cache of peripherals to avoid creating new ones every time
  @MainActor private(set) static var storedPeripherals: [UUID: Peripheral] = [:]

  @MainActor static func getOrCreatePeripheral(cbPeripheral: CBMPeripheral) -> Peripheral {
    if let peripheral = storedPeripherals[cbPeripheral.identifier] {
      return peripheral
    } else {
      let peripheral = Peripheral(cbPeripheral: cbPeripheral)
      storedPeripherals[cbPeripheral.identifier] = peripheral
      return peripheral
    }
  }

  @MainActor static func getPeripheral(cbPeripheral: CBMPeripheral) -> Peripheral? {
    storedPeripherals[cbPeripheral.identifier]
  }

  @MainActor static func getPeripheral(peripheralUUID: UUID) -> Peripheral? {
    storedPeripherals[peripheralUUID]
  }

  @MainActor private init(cbPeripheral: CBMPeripheral) {
    self.cbPeripheral = cbPeripheral
    identifier = cbPeripheral.identifier
    name = cbPeripheral.name
  }

  func setConnectionState(_ state: ConnectionState) async {
    await MainActor.run {
      connectionState = state
    }
  }

//  var state: PeripheralState {
//    cbPeripheral.state
//  }

  var services: [CBMService]?
}

// extension Peripheral: Identifiable {
//  public static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
//    lhs.identifier == rhs.identifier
//  }
// }

extension Peripheral: Identifiable, Equatable {
  public static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
    lhs.identifier == rhs.identifier
  }
}

extension Peripheral: Hashable {
  public static func != (lhs: Peripheral, rhs: Peripheral) -> Bool {
    return lhs.identifier != rhs.identifier
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
}
