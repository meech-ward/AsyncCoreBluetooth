import CoreBluetooth
import CoreBluetoothMock

/// `Service` objects represent services of a remote peripheral. Services are either primary or secondary and
/// may contain multiple characteristics or included services (references to other services).
public actor Service: Identifiable {

  @Observable
  @MainActor
  public class State {
    // public internal(set) var identifier: UUID
    public internal(set) var uuid: CBMUUID
    public internal(set) var isPrimary: Bool
    public internal(set) var characteristics: [Characteristic]?
    init(uuid: CBMUUID, isPrimary: Bool) {
      // self.identifier = identifier
      self.uuid = uuid
      self.isPrimary = isPrimary
    }
  }
  @MainActor
  public private(set) var state: State!
  // public let identifier: UUID
  public let uuid: CBMUUID
  /// The type of the service (primary or secondary).
  public let isPrimary: Bool

  let service: CBMService

  /// A list of a peripheral’s discovered characteristics.
  public var characteristics: [Characteristic]? {
    willSet {
      Task { @MainActor in
        self.state.characteristics = newValue
      }
    }
  }
  func setCharacteristics(_ characteristics: [Characteristic]) {
    self.characteristics = characteristics
  }
  // var includedServices: [CBMService]?

  public internal(set) weak var peripheral: Peripheral?

  init(service: CBMService, peripheral: Peripheral?) async {
    // self.identifier = UUID()
    self.uuid = service.uuid
    self.isPrimary = service.isPrimary
    self.service = service
    self.peripheral = peripheral
    await MainActor.run {
      self.state = State(uuid: self.uuid, isPrimary: self.isPrimary)
    }
  }
}
