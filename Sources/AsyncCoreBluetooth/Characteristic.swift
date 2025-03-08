import AsyncObservable
import CoreBluetooth
import CoreBluetoothMock

/// A characteristic of a remote peripheral’s service.
///
/// Note about value:
/// cbCharacteristic.value does not reflect the current operation’s result.
/// It's a historical record, and the error parameter is the real-time status.
/// Because of this, there are two properties:
/// - value: the historical record
/// - error: the real-time status
/// And they are seperated from each other. And have to be handled seperately.
///
public actor Characteristic: Identifiable {

  @MainActor
  public let uuid: CBMUUID
  @MainActor
  private let _value: AsyncObservable<Data?> = .init(nil)
  @MainActor
  public var value: any AsyncObservableReadOnly<Data?> { _value }
  @MainActor
  private let _error: AsyncObservable<Error?> = .init(nil)
  @MainActor
  public var error: any AsyncObservableReadOnly<Error?> { _error }
  @MainActor
  private let _isNotifying: AsyncObservable<Bool> = .init(false)
  @MainActor
  public var isNotifying: any AsyncObservableReadOnly<Bool> { _isNotifying }

  public internal(set) weak var service: Service?

  public let characteristic: CBMCharacteristic

  public let properties: CBCharacteristicProperties

  init(characteristic: CBMCharacteristic, service: Service?) async {
    self.uuid = characteristic.uuid
    self.characteristic = characteristic
    self.properties = characteristic.properties
    self.service = service
  }

  func update(result: Result<Data, Error>) {
    switch result {
    case .success(let value):
      _value.update(value)
      _error.update(nil)
    case .failure(let error):
      _error.update(error)
    }
  }

  func update(isNotifying: Bool) {
    _isNotifying.update(isNotifying)
  }
}
