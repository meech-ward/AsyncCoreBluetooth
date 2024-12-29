import CoreBluetooth
import CoreBluetoothMock

/// `Service` objects represent services of a remote peripheral. Services are either primary or secondary and
/// may contain multiple characteristics or included services (references to other services).
public actor Service: Identifiable {

  @Observable
  @MainActor
  public class State {
    public internal(set) var identifier: UUID
    public internal(set) var uuid: CBMUUID
    public internal(set) var isPrimary: Bool
    init(identifier: UUID, uuid: CBMUUID, isPrimary: Bool) {
      self.identifier = identifier
      self.uuid = uuid
      self.isPrimary = isPrimary
    }
  }
  @MainActor
  public private(set) var state: State!
  public let identifier: UUID
  public let uuid: CBMUUID
  /// The type of the service (primary or secondary).
  public let isPrimary: Bool

  private let service: CBMService

  public var characteristics: [CBMCharacteristic]?
  // var includedServices: [CBMService]?

  public internal(set) weak var peripheral: CBMPeripheral?

  init(service: CBMService) async {
    self.identifier = UUID()
    self.uuid = service.uuid
    self.isPrimary = service.isPrimary
    self.service = service
    await MainActor.run {
      self.state = State(identifier: self.identifier, uuid: self.uuid, isPrimary: self.isPrimary)
    }
  }
}
