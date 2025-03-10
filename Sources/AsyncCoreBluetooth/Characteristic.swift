import AsyncObservable
import CoreBluetooth
import CoreBluetoothMock

/// A characteristic of a remote peripheral's service.
///
/// Characteristics are the primary means of communicating with a Bluetooth peripheral. Each characteristic 
/// represents a specific piece of functionality or data on the peripheral. Characteristics can be:
/// - Read: To retrieve data from the peripheral
/// - Written: To send data to the peripheral
/// - Notify/Indicate: To receive updates when the characteristic's value changes
///
/// The properties of a characteristic determine which operations are supported. Use the `properties` 
/// property to check which operations are available for a specific characteristic.
///
/// Example Usage:
/// ```swift
/// do {
///   // Discover a characteristic
///   let heartRateService = try await peripheral.discoverService(CBUUID(string: "180D"))
///   let heartRateMeasurement = try await peripheral.discoverCharacteristic(CBUUID(string: "2A37"), for: heartRateService)
///   
///   // Enable notifications
///   try await peripheral.setNotifyValue(true, for: heartRateMeasurement)
///   
///   // Observe value changes
///   Task {
///     for await value in heartRateMeasurement.value {
///       let heartRate = parseHeartRateData(value)
///       print("Heart rate: \(heartRate) bpm")
///     }
///   }
///   
///   // Or directly read a value
///   let batteryService = try await peripheral.discoverService(CBUUID(string: "180F"))
///   let batteryLevel = try await peripheral.discoverCharacteristic(CBUUID(string: "2A19"), for: batteryService)
///   let data = try await peripheral.readValue(for: batteryLevel)
///   print("Battery level: \(data[0])%")
/// } catch {
///   print("Error: \(error)")
/// }
/// ```
///
/// Note about value and error handling:
/// The CoreBluetooth characteristic's value property doesn't always reflect the current operation's result.
/// It can contain historical data from previous operations. To handle this, the Characteristic actor 
/// provides separate observable streams for value updates and errors, allowing you to correctly
/// track the real-time status of operations and their results.
///
public actor Characteristic: Identifiable {

  /// The UUID that identifies the characteristic.
  ///
  /// Standard Bluetooth characteristics have well-known UUIDs defined by the Bluetooth SIG,
  /// while custom characteristics have UUIDs defined by the peripheral's manufacturer.
  /// You can use this UUID to identify the purpose of the characteristic.
  ///
  /// Example:
  /// ```swift
  /// if characteristic.uuid == CBUUID(string: "2A37") {
  ///   print("This is a heart rate measurement characteristic")
  /// }
  /// ```
  @MainActor
  public let uuid: CBMUUID

  /// The current value of the characteristic as an observable property.
  ///
  /// This property is updated whenever new data is read from the characteristic or 
  /// received through notifications. Use this property to observe value changes.
  ///
  /// Example:
  /// ```swift
  /// Task {
  ///   for await data in characteristic.value {
  ///     print("New value: \(data.hexString)")
  ///     // Process the data based on the characteristic type
  ///   }
  /// }
  /// ```
  @MainActor
  private let _value: AsyncObservableUnwrapped<Data> = .init(nil)
  @MainActor
  public var value: some AsyncObservableUnwrappedStreamReadOnly<Data> { _value }

  /// The error associated with the most recent operation on this characteristic.
  ///
  /// This property is updated when an error occurs during read, write, or notification operations.
  /// It's set to nil when operations succeed. You can observe this property to handle errors.
  ///
  /// Example:
  /// ```swift
  /// Task {
  ///   for await error in characteristic.error {
  ///     if let error = error {
  ///       print("Error occurred: \(error.localizedDescription)")
  ///     } else {
  ///       print("Operation completed successfully")
  ///     }
  ///   }
  /// }
  /// ```
  @MainActor
  private let _error: AsyncObservable<Error?> = .init(nil)
  @MainActor
  public var error: some AsyncObservableReadOnly<Error?> { _error }

  /// Indicates whether notifications or indications are currently enabled for this characteristic.
  ///
  /// This property is true if the peripheral is sending notifications or indications when the 
  /// characteristic's value changes. Use this to check the current notification state.
  ///
  /// Example:
  /// ```swift
  /// if await characteristic.isNotifying.current {
  ///   print("Notifications are enabled")
  /// } else {
  ///   print("Notifications are disabled")
  /// }
  /// ```
  @MainActor
  private let _isNotifying: AsyncObservable<Bool> = .init(false)
  @MainActor
  public var isNotifying: some AsyncObservableReadOnly<Bool> { _isNotifying }

  /// The service this characteristic belongs to.
  ///
  /// This property provides access to the parent service of this characteristic.
  /// It's a weak reference to avoid reference cycles.
  public internal(set) weak var service: Service?

  /// The underlying CoreBluetooth characteristic object.
  ///
  /// This provides direct access to the CoreBluetooth characteristic if needed,
  /// but typically you should use the methods provided by the Peripheral actor
  /// to interact with characteristics.
  public let characteristic: CBMCharacteristic

  /// The properties of the characteristic that determine what operations are supported.
  ///
  /// You can check these properties to determine if a characteristic supports reading,
  /// writing, notifications, etc.
  ///
  /// Example:
  /// ```swift
  /// if characteristic.properties.contains(.read) {
  ///   print("Characteristic supports reading")
  /// }
  /// if characteristic.properties.contains(.notify) {
  ///   print("Characteristic supports notifications")
  /// }
  /// if characteristic.properties.contains(.write) {
  ///   print("Characteristic supports writing with response")
  /// }
  /// if characteristic.properties.contains(.writeWithoutResponse) {
  ///   print("Characteristic supports writing without response")
  /// }
  /// ```
  public let properties: CBCharacteristicProperties

  /// Initialize a new Characteristic.
  ///
  /// This initializer is internal and should not be called directly.
  /// Characteristics are created automatically during the discovery process.
  init(characteristic: CBMCharacteristic, service: Service?) async {
    self.uuid = characteristic.uuid
    self.characteristic = characteristic
    self.properties = characteristic.properties
    self.service = service
  }

  /// Updates the characteristic's value and error state.
  ///
  /// This method is called internally when new data is received for the characteristic.
  /// - Parameter result: A Result containing either the new Data value or an Error.
  func update(result: Result<Data, Error>) {
    switch result {
    case .success(let value):
      _value.update(value)
      _error.update(nil)
    case .failure(let error):
      _error.update(error)
    }
  }

  /// Updates the notification state of the characteristic.
  ///
  /// This method is called internally when the notification state changes.
  /// - Parameter isNotifying: The new notification state.
  func update(isNotifying: Bool) {
    _isNotifying.update(isNotifying)
  }
}
