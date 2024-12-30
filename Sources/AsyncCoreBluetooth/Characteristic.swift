import CoreBluetooth
import CoreBluetoothMock

/// A characteristic of a remote peripheral’s service.
public actor Characteristic: Identifiable {

  @Observable
  @MainActor
  public class State {
    public internal(set) var uuid: CBMUUID
    public internal(set) var value: Data?
    public internal(set) var isNotifying: Bool = false
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

  public internal(set) var isNotifying: Bool = false {
    willSet {
      Task { @MainActor in
        self.state.isNotifying = newValue
      }
    }
  }
  func setIsNotifying(_ isNotifying: Bool) {
    self.isNotifying = isNotifying
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

  var characteristicValueContinuations: [UUID: AsyncStream<Result<Data?, Error>>.Continuation] = [:]

  func setCharacteristicValueContinuation(
    id: UUID, continuation: AsyncStream<Result<Data?, Error>>.Continuation?
  ) {
    characteristicValueContinuations[id] = continuation
  }

  /// Get an async stream representing the characteristic's value.
  /// This is most useful when the characteristic is notifying.
  /// The value will be the same as characteristic.value.
  public func valueStream() async -> AsyncStream<Result<Data?, Error>> {
    return AsyncStream { continuation in
      let id = UUID()

      self.setCharacteristicValueContinuation(
        id: id, continuation: continuation)

      continuation.yield(Result.success(self.value))

      continuation.onTermination = { _ in
        Task {
          await self.setCharacteristicValueContinuation(id: id, continuation: nil)
        }
      }
    }
  }
}
