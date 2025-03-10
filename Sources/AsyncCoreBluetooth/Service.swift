import AsyncObservable
import CoreBluetooth
import CoreBluetoothMock

/// `Service` objects represent services of a remote peripheral. Services are either primary or secondary and
/// may contain multiple characteristics or included services (references to other services).
///
/// A Bluetooth peripheral organizes its functionality into services, each representing a specific
/// feature or capability of the device. For example, a heart rate monitor peripheral might have a
/// Heart Rate Service, Battery Service, and Device Information Service.
///
/// You don't create Service objects directly. Instead, they are discovered through the Peripheral's
/// discoverServices method. Once you have a Service object, you can discover its characteristics
/// to interact with specific functionality.
///
/// Example Usage:
/// ```swift
/// do {
///   // Discover services
///   let services = try await peripheral.discoverServices(nil)
///   
///   // Find a specific service
///   let heartRateServiceUUID = CBUUID(string: "180D")
///   if let heartRateService = services[heartRateServiceUUID] {
///     print("Found heart rate service")
///     
///     // Discover characteristics for this service
///     let characteristics = try await peripheral.discoverCharacteristics(nil, for: heartRateService)
///     
///     // Process the characteristics
///     for (uuid, characteristic) in characteristics {
///       print("Found characteristic: \(uuid)")
///     }
///   }
/// } catch {
///   print("Error: \(error)")
/// }
/// ```
public actor Service: Identifiable {

  /// The characteristics discovered for this service.
  ///
  /// This property is an AsyncObservable that will update when characteristics are discovered.
  /// The value is nil until characteristics have been discovered using the peripheral's 
  /// `discoverCharacteristics(_:for:)` method.
  ///
  /// Example Usage:
  /// ```swift
  /// Task {
  ///   for await characteristics in service.characteristics {
  ///     if let characteristics = characteristics {
  ///       print("Discovered \(characteristics.count) characteristics")
  ///       for characteristic in characteristics {
  ///         print("Characteristic: \(characteristic.uuid)")
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  @MainActor
  internal let _characteristics: AsyncObservable<[Characteristic]?> = .init(nil)
  @MainActor
  public var characteristics: some AsyncObservableReadOnly<[Characteristic]?> { _characteristics }
  // public let identifier: UUID
  
  /// The UUID that identifies the service.
  ///
  /// Standard Bluetooth services have well-known UUIDs defined by the Bluetooth SIG,
  /// while custom services have UUIDs defined by the peripheral's manufacturer.
  /// You can use this UUID to identify the purpose of the service.
  ///
  /// Example:
  /// ```swift
  /// if service.uuid == CBUUID(string: "180D") {
  ///   print("This is a heart rate service")
  /// } else if service.uuid == CBUUID(string: "180F") {
  ///   print("This is a battery service")
  /// }
  /// ```
  @MainActor
  public let uuid: CBMUUID
  
  /// The type of the service (primary or secondary).
  ///
  /// Primary services represent the main functionality of a peripheral.
  /// Secondary services are only meaningful in the context of other services
  /// and are typically referenced by primary services.
  ///
  /// Example:
  /// ```swift
  /// if service.isPrimary {
  ///   print("This is a primary service")
  /// } else {
  ///   print("This is a secondary service")
  /// }
  /// ```
  @MainActor
  public let isPrimary: Bool

  /// The underlying CoreBluetooth service object.
  ///
  /// This provides direct access to the CoreBluetooth service if needed.
  /// Typically, you should use the properties and methods provided by the Service actor
  /// instead of accessing this property directly.
  let service: CBMService

  /// Updates the characteristics discovered for this service.
  ///
  /// This method is called internally when characteristics are discovered.
  /// - Parameter characteristics: An array of discovered Characteristic objects.
  func setCharacteristics(_ characteristics: [Characteristic]) {
    _characteristics.update(characteristics)
  }
  // var includedServices: [CBMService]?

  /// The peripheral this service belongs to.
  ///
  /// This property provides access to the parent peripheral of this service.
  /// It's a weak reference to avoid reference cycles.
  public internal(set) weak var peripheral: Peripheral?

  /// Initialize a new Service.
  ///
  /// This initializer is internal and should not be called directly.
  /// Services are created automatically during the discovery process.
  init(service: CBMService, peripheral: Peripheral?) async {
    // self.identifier = UUID()
    self.uuid = service.uuid
    self.isPrimary = service.isPrimary
    self.service = service
    self.peripheral = peripheral
  }
}
