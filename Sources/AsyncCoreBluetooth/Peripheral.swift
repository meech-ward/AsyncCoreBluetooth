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

  @MainActor public private(set) var identifier: UUID 
  @MainActor @Published public internal(set) var connectionState: ConnectionState = .disconnected(nil)
  @MainActor @Published public private(set) var name: String?

  var delegate: CBMPeripheralDelegate?

  @MainActor init(cbPeripheral: CBMPeripheral) {
    self.cbPeripheral = cbPeripheral
    identifier = cbPeripheral.identifier
    name = cbPeripheral.name
  }

  func setConnectionState(_ state: ConnectionState) async {
    await MainActor.run {
      connectionState = state
    }
  }

  // var state: PeripheralState {
  //   peripheral.state
  // }

  var services: [CBMService]?
}
