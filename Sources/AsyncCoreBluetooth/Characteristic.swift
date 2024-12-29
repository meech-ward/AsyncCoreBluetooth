import CoreBluetooth
import CoreBluetoothMock

/// A characteristic of a remote peripheral’s service.
public actor Characteristic: Identifiable {

  @Observable
  @MainActor
  public class State {
    public internal(set) var uuid: CBMUUID
    public internal(set) var value: Data?

    init(uuid: CBMUUID) {

      self.uuid = uuid
    }
  }
  @MainActor
  public private(set) var state: State!
  public let uuid: CBMUUID

  public internal(set) var value: Data? {
    willSet {
      Task { @MainActor in
        self.state.value = newValue
      }
    }
  }
  func setValue(_ value: Data?) {
    self.value = value
  }

  public internal(set) weak var service: Service?

  public let characteristic: CBMCharacteristic

  public let properties: CBCharacteristicProperties

  init(characteristic: CBMCharacteristic, service: Service?) async {
    self.uuid = characteristic.uuid
    self.characteristic = characteristic
    self.properties = characteristic.properties
    self.service = service
    await MainActor.run {
      self.state = State(uuid: self.uuid)
    }
  }
}
