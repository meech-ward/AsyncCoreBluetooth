import CoreBluetooth
import CoreBluetoothMock
import Foundation

public actor Peripheral: ObservableObject {
  public enum ConnectionState {
    case disconnected(CBError?)
    case connecting
    case connected
    case disconnecting
    case failedToConnect(CBError)
  }

  public private(set) var cbPeripheral: CBMPeripheral

  public var identifier: UUID {
    cbPeripheral.identifier
  }

  @MainActor @Published public internal(set) var connectionState: ConnectionState = .disconnected(nil)
  @MainActor @Published public var name: String?

  var delegate: CBMPeripheralDelegate?

  init(cbPeripheral: CBMPeripheral) {
    self.cbPeripheral = cbPeripheral
  }



  // var state: PeripheralState {
  //   peripheral.state
  // }

  var services: [CBMService]?
}