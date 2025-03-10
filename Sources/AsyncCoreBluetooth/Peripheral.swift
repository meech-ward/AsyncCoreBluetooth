import AsyncObservable
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import DequeModule
import Foundation

/// The possible states of a peripheral connection.
///
/// The connection state transitions typically follow these patterns:
/// - Normal connection: `.disconnected` → `.connecting` → `.connected`
/// - Normal disconnection: `.connected` → `.disconnecting` → `.disconnected`
/// - Failed connection: `.disconnected` → `.connecting` → `.failedToConnect`
/// - Unexpected disconnection: `.connected` → `.disconnected(error)`
///
/// You can observe these state changes using the peripheral's `connectionState` property.
public enum PeripheralConnectionState: Equatable, Sendable {
  case disconnected(CBError?)
  case connecting
  case connected
  case disconnecting
  case failedToConnect(CBError)

  /// Returns a string representation of the connection state.
  /// - Returns: A human-readable string describing the current state.
  public var description: String {
    switch self {
    case .disconnected(let error):
      return "Disconnected" + (error.map { ": \($0.localizedDescription)" } ?? "")
    case .connecting:
      return "Connecting"
    case .connected:
      return "Connected"
    case .disconnecting:
      return "Disconnecting"
    case .failedToConnect(let error):
      return "Failed to connect: \(error.localizedDescription)"
    }
  }
}

/// The Peripheral actor represents remote peripheral devices that your app discovers with a central manager.
///
/// Peripherals use UUIDs to identify themselves.
/// Peripherals may contain one or more services or provide useful information about their connected signal strength.
///
/// You use this actor to discover, explore, and interact with the services available on a remote peripheral that supports Bluetooth low energy.
/// A service encapsulates the way part of the device behaves. For example, one service of a heart rate monitor may be to expose heart rate data from a sensor.
/// Services themselves contain of characteristics or included services (references to other services). Characteristics provide further details about a peripheral's service. For example, the heart rate service may contain multiple characteristics. One characteristic could describe the intended body location of the device's heart rate sensor, and another characteristic could transmit the heart rate measurement data.
/// Finally, characteristics contain any number of descriptors that provide more information about the characteristic's value, such as a human-readable description and a way to format the value.
///
/// You don't create Peripheral instances directly. Instead, you receive them from the central manager when you discover, connect to, or retrieve connected peripherals.
public actor Peripheral {

  /// The name of the peripheral.
  ///
  /// This property is an AsyncObservable that will update if the peripheral's name changes.
  /// The name is typically advertised by the peripheral and may be nil if no name is provided.
  ///
  /// Example Usage:
  /// ```swift
  /// Task {
  ///   for await name in peripheral.name {
  ///     if let name = name {
  ///       print("Peripheral name updated to: \(name)")
  ///     } else {
  ///       print("Peripheral has no name")
  ///     }
  ///   }
  /// }
  /// ```
  @MainActor
  public var name: some AsyncObservableReadOnly<String?> { _name }
  @MainActor
  internal let _name: AsyncObservable<String?> = .init(nil)

  /// The current connection state of this peripheral.
  ///
  /// This property is an AsyncObservable that will update as the peripheral's connection state changes.
  /// You can use this to monitor connection and disconnection events.
  ///
  /// Example Usage:
  /// ```swift
  /// Task {
  ///   for await state in peripheral.connectionState.stream {
  ///     switch state {
  ///     case .connected:
  ///       print("Connected to peripheral")
  ///       try await peripheral.discoverServices(nil)
  ///     case .disconnected(let error):
  ///       if let error = error {
  ///         print("Disconnected with error: \(error.localizedDescription)")
  ///       } else {
  ///         print("Disconnected normally")
  ///       }
  ///     case .connecting:
  ///       print("Connecting to peripheral...")
  ///     case .disconnecting:
  ///       print("Disconnecting from peripheral...")
  ///     case .failedToConnect(let error):
  ///       print("Failed to connect: \(error.localizedDescription)")
  ///     }
  ///   }
  /// }
  /// ```
  @MainActor
  public var connectionState: some AsyncObservableReadOnly<PeripheralConnectionState> { _connectionState }
  @MainActor
  internal let _connectionState: AsyncObservable<PeripheralConnectionState> = .init(.disconnected(nil))

  /// A list of the peripheral's discovered services.
  ///
  /// This property is an AsyncObservable that will update when services are discovered.
  /// The value is nil until services have been discovered using `discoverServices(_:)`.
  ///
  /// Example Usage:
  /// ```swift
  /// Task {
  ///   for await services in peripheral.services.stream {
  ///     if let services = services {
  ///       print("Discovered \(services.count) services")
  ///       for service in services {
  ///         print("Service: \(service.uuid)")
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  @MainActor
  public var services: some AsyncObservableReadOnly<[Service]?> { _services }
  @MainActor
  internal let _services: AsyncObservable<[Service]?> = .init(nil)

  // MARK: - Peripheral Properties

  /// The underlying `CBMPeripheral` instance.
  ///
  /// Avoid using this if you can. It's been left public in case this library missed some functionality
  /// that is only available in the underlying `CBMPeripheral`.
  public private(set) var cbPeripheral: CBMPeripheral

  /// The unique identifier associated with the peripheral.
  ///
  /// This UUID uniquely identifies the peripheral and can be used to retrieve the peripheral later
  /// using the central manager's `retrievePeripheral(withIdentifier:)` method.
  @MainActor
  public let identifier: UUID

  /// An optional delegate for a more classical implementation.
  ///
  /// The delegate methods will get called straight from the CBMPeripheral delegate without going through
  /// the Peripheral actor. Avoid using this if you can and just use async streams.
  /// However, if you really need to use the delegate, you can pass it in here.
  /// This will not affect the async streams.
  public var delegate: CBMPeripheralDelegate?

  private var peripheralDelegate: PeripheralDelegate?

  var discoverServicesContinuations = Deque<CheckedContinuation<[CBUUID /* service uuid */: Service], Error>>()
  var discoverCharacteristicsContinuations: [CBUUID /* service uuid */: Deque<CheckedContinuation<[CBUUID /* characteristic uuid */: Characteristic], Error>>] = [:]

  var readCharacteristicValueContinuations: [CBUUID: Deque<CheckedContinuation<Data, Error>>] = [:]
  var writeCharacteristicWithResponseContinuations: Deque<CheckedContinuation<Void, any Error>> = Deque<CheckedContinuation<Void, Error>>()
  var notifyCharacteristicValueContinuations: [CBUUID: Deque<CheckedContinuation<Bool, Error>>] = [:]

  // MARK: - Peripheral Connection State

  func setConnectionState(_ state: PeripheralConnectionState) async {
    _connectionState.update(state)

    if case .disconnected = state {
      // cancel all discovery continuations
      for discoverCharacteristicsContinuation in discoverCharacteristicsContinuations {
        discoverCharacteristicsContinuation.value.forEach { $0.resume(throwing: PeripheralConnectionError.disconnectedWhileWorking) }
      }
      discoverCharacteristicsContinuations.removeAll()
      for discoverServicesContinuation in discoverServicesContinuations {
        discoverServicesContinuation.resume(throwing: PeripheralConnectionError.disconnectedWhileWorking)
      }
      discoverServicesContinuations.removeAll()

      for readCharacteristicValueContinuation in readCharacteristicValueContinuations {
        readCharacteristicValueContinuation.value.forEach { $0.resume(throwing: PeripheralConnectionError.disconnectedWhileWorking) }
      }
      readCharacteristicValueContinuations.removeAll()

      for writeCharacteristicWithResponseContinuation in writeCharacteristicWithResponseContinuations {
        writeCharacteristicWithResponseContinuation.resume(throwing: PeripheralConnectionError.disconnectedWhileWorking)
      }
      writeCharacteristicWithResponseContinuations.removeAll()

      for notifyCharacteristicValueContinuation in notifyCharacteristicValueContinuations {
        notifyCharacteristicValueContinuation.value.forEach { $0.resume(throwing: PeripheralConnectionError.disconnectedWhileWorking) }
      }
      notifyCharacteristicValueContinuations.removeAll()

      // My assumption is that somewhere there is a loop listening for the connection state
      // On disconnect, the workflow for discovering and connection should be re triggered
      // Canceling the discovery continuations allows discover to block then be re triggered with the above assumptions
      // If code is listening for results of read, write, notify, that task is canceled and needs regenerated by the caller
      // The characteristic objects should be fine and not necessarily need to be recreated, but peripheral delegate dependencies do
    }
  }

  // MARK: - Peripheral Creation

  private init(cbPeripheral: CBMPeripheral) async {
    self.cbPeripheral = cbPeripheral
    identifier = cbPeripheral.identifier
    _name.update(cbPeripheral.name)
    let peripheralDelegate = PeripheralDelegate(peripheral: self)
    cbPeripheral.delegate = peripheralDelegate
    self.peripheralDelegate = peripheralDelegate
  }

  // MARK: - Peripheral Creation and Caching

  static func createPeripheral(cbPeripheral: CBMPeripheral) async -> Peripheral {
    let peripheral = await Peripheral(cbPeripheral: cbPeripheral)
    await PeripheralStore.shared.store(peripheral, for: cbPeripheral.identifier)
    return peripheral
  }

  static func getPeripheral(cbPeripheral: CBMPeripheral) async -> Peripheral? {
    await PeripheralStore.shared.getPeripheral(for: cbPeripheral.identifier)
  }

  static func getPeripheral(peripheralUUID: UUID) async -> Peripheral? {
    await PeripheralStore.shared.getPeripheral(for: peripheralUUID)
  }

}

// MARK: - Discovering Services
extension Peripheral {
  // https://developer.apple.com/documentation/corebluetooth/cbperipheral#1667320

  /// Discovers the specified services of the peripheral.
  ///
  /// This method initiates a service discovery process on the peripheral. When the discovery completes,
  /// the method returns a dictionary mapping service UUIDs to Service objects.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   // Discover all services
  ///   let services = try await peripheral.discoverServices(nil)
  ///
  ///   // Or discover specific services
  ///   let heartRateServiceUUID = CBUUID(string: "180D")
  ///   let services = try await peripheral.discoverServices([heartRateServiceUUID])
  ///
  ///   for (uuid, service) in services {
  ///     print("Discovered service: \(uuid)")
  ///   }
  /// } catch {
  ///   print("Error discovering services: \(error)")
  /// }
  /// ```
  ///
  /// - Parameter serviceUUIDs: An array of service UUIDs to discover, or nil to discover all services.
  /// - Returns: A dictionary mapping service UUIDs to discovered Service objects.
  /// - Throws: An error if service discovery fails or if the peripheral disconnects during discovery.
  @discardableResult
  public func discoverServices(_ serviceUUIDs: [CBUUID]?) async throws -> [CBUUID /* service uuid */: Service] {
    print("discover services \(self.identifier) \(ObjectIdentifier(self))")
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        discoverServicesContinuations.append(continuation)
        cbPeripheral.discoverServices(serviceUUIDs)
      }
    } onCancel: {
      // need to figure out how to cancel this nicely
    }
  }

  /// Discovers a specific service by UUID.
  ///
  /// This is a convenience method that discovers a single service by its UUID.
  /// It will throw an error if the service is not found.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   let heartRateServiceUUID = CBUUID(string: "180D")
  ///   let heartRateService = try await peripheral.discoverService(heartRateServiceUUID)
  ///   print("Found heart rate service")
  /// } catch {
  ///   print("Heart rate service not found: \(error)")
  /// }
  /// ```
  ///
  /// - Parameter serviceUUID: The UUID of the service to discover.
  /// - Returns: The discovered Service object.
  /// - Throws: `ServiceError.unableToFindServices` if the service is not found,
  ///           or other errors if service discovery fails.
  @discardableResult
  public func discoverService(_ serviceUUID: CBUUID) async throws -> Service {
    guard let service = try await discoverServices([serviceUUID])[serviceUUID] else {
      throw ServiceError.unableToFindServices
    }
    return service
  }

  // public func discoverServices(serviceUUIDs: [UUID]?) async -> [Service] {
  //   return await discoverServices(serviceUUIDs?.map { CBUUID(nsuuid: $0) })
  // }

  /// Discovers the specified included services of a previously-discovered service.
  public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: Service) {}

  // MARK: - Discovering Characteristics

  /// Discovers the characteristics for a specified service.
  ///
  /// This method initiates a characteristic discovery process for the specified service.
  /// When the discovery completes, the method returns a dictionary mapping characteristic UUIDs
  /// to Characteristic objects.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   // First discover a service
  ///   let heartRateServiceUUID = CBUUID(string: "180D")
  ///   let heartRateService = try await peripheral.discoverService(heartRateServiceUUID)
  ///
  ///   // Then discover all characteristics for that service
  ///   let characteristics = try await peripheral.discoverCharacteristics(nil, for: heartRateService)
  ///
  ///   // Or discover specific characteristics
  ///   let heartRateMeasurementUUID = CBUUID(string: "2A37")
  ///   let characteristics = try await peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: heartRateService)
  ///
  ///   for (uuid, characteristic) in characteristics {
  ///     print("Discovered characteristic: \(uuid)")
  ///   }
  /// } catch {
  ///   print("Error discovering characteristics: \(error)")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - characteristicUUIDs: An array of characteristic UUIDs to discover, or nil to discover all characteristics.
  ///   - service: The service to discover characteristics for.
  /// - Returns: A dictionary mapping characteristic UUIDs to discovered Characteristic objects.
  /// - Throws: An error if characteristic discovery fails or if the peripheral disconnects during discovery.
  @discardableResult
  public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: Service) async throws -> [CBUUID: Characteristic] {
    return try await withCheckedThrowingContinuation { continuation in
      if discoverCharacteristicsContinuations[service.uuid] == nil {
        discoverCharacteristicsContinuations[service.uuid] = []
      }
      discoverCharacteristicsContinuations[service.uuid]?.append(continuation)
      cbPeripheral.discoverCharacteristics(characteristicUUIDs, for: service.service)
    }
  }

  /// Discovers a specific characteristic by UUID for a given service.
  ///
  /// This is a convenience method that discovers a single characteristic by its UUID.
  /// It will throw an error if the characteristic is not found.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   let heartRateServiceUUID = CBUUID(string: "180D")
  ///   let heartRateService = try await peripheral.discoverService(heartRateServiceUUID)
  ///
  ///   let heartRateMeasurementUUID = CBUUID(string: "2A37")
  ///   let heartRateCharacteristic = try await peripheral.discoverCharacteristic(heartRateMeasurementUUID, for: heartRateService)
  ///
  ///   // Now you can read from or write to the characteristic
  /// } catch {
  ///   print("Error: \(error)")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - characteristicUUID: The UUID of the characteristic to discover.
  ///   - service: The service to discover the characteristic in.
  /// - Returns: The discovered Characteristic object.
  /// - Throws: `CharacteristicError.unableToFindCharacteristics` if the characteristic is not found,
  ///           or other errors if characteristic discovery fails.
  @discardableResult
  public func discoverCharacteristic(_ characteristicUUID: CBUUID, for service: Service) async throws -> Characteristic {
    guard let characteristic = try await discoverCharacteristics([characteristicUUID], for: service)[characteristicUUID] else {
      throw CharacteristicError.unableToFindCharacteristics
    }
    return characteristic
  }
}

// MARK: - Read, Write, Notify

extension Peripheral {
  /// Reads the value of a characteristic.
  ///
  /// This method initiates a read operation for the specified characteristic.
  /// When the read completes, the method returns the characteristic's value as Data.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   let data = try await peripheral.readValue(for: characteristic)
  ///   print("Read value: \(data.hexString)")
  ///
  ///   // Parse the data based on the characteristic type
  ///   if characteristic.uuid == heartRateMeasurementUUID {
  ///     let heartRate = parseHeartRateData(data)
  ///     print("Heart rate: \(heartRate) bpm")
  ///   }
  /// } catch {
  ///   print("Error reading characteristic: \(error)")
  /// }
  /// ```
  ///
  /// - Parameter characteristic: The characteristic to read from.
  /// - Returns: The characteristic's value as Data.
  /// - Throws: An error if the read operation fails or if the peripheral disconnects during the read.
  @discardableResult
  public func readValue(for characteristic: Characteristic) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
      if readCharacteristicValueContinuations[characteristic.uuid] == nil {
        readCharacteristicValueContinuations[characteristic.uuid] = []
      }
      readCharacteristicValueContinuations[characteristic.uuid]?.append(continuation)
      cbPeripheral.readValue(for: characteristic.characteristic)
    }
  }

  /// Writes a value to a characteristic and waits for a response.
  ///
  /// This method writes data to the specified characteristic and waits for a confirmation
  /// from the peripheral before returning. This is known as a "write with response" operation.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   let data = Data([0x01, 0x02, 0x03])
  ///   try await peripheral.writeValueWithResponse(data, for: characteristic)
  ///   print("Write completed successfully")
  /// } catch {
  ///   print("Error writing to characteristic: \(error)")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - value: The data to write to the characteristic.
  ///   - characteristic: The characteristic to write to.
  /// - Throws: An error if the write operation fails or if the peripheral disconnects during the write.
  public func writeValueWithResponse(_ value: Data, for characteristic: Characteristic) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      writeCharacteristicWithResponseContinuations.append(continuation)
      cbPeripheral.writeValue(value, for: characteristic.characteristic, type: .withResponse)
    }
  }

  /// Writes a value to a characteristic without waiting for a response.
  ///
  /// This method writes data to the specified characteristic without waiting for a confirmation.
  /// This is known as a "write without response" operation and is typically faster but less reliable.
  ///
  /// Example Usage:
  /// ```swift
  /// let data = Data([0x01, 0x02, 0x03])
  /// peripheral.writeValueWithoutResponse(data, for: characteristic)
  /// print("Write request sent")
  /// ```
  ///
  /// - Parameters:
  ///   - value: The data to write to the characteristic.
  ///   - characteristic: The characteristic to write to.
  public func writeValueWithoutResponse(_ value: Data, for characteristic: Characteristic) {
    cbPeripheral.writeValue(value, for: characteristic.characteristic, type: .withoutResponse)
  }

  /// Enables or disables notifications/indications for a characteristic's value.
  ///
  /// This method subscribes to or unsubscribes from notifications for changes to the characteristic's value.
  /// Once notifications are enabled, you can observe value changes through the characteristic's
  /// `valueDidUpdate` AsyncObservable property.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   // Enable notifications
  ///   try await peripheral.setNotifyValue(true, for: characteristic)
  ///
  ///   // Observe value changes
  ///   Task {
  ///     for await value in characteristic.valueDidUpdate {
  ///       print("Characteristic value updated: \(value.hexString)")
  ///     }
  ///   }
  ///
  ///   // Later, disable notifications
  ///   try await peripheral.setNotifyValue(false, for: characteristic)
  /// } catch {
  ///   print("Error setting notifications: \(error)")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - enabled: true to enable notifications, false to disable them.
  ///   - characteristic: The characteristic to enable notifications for.
  /// - Returns: true if the request was sent successfully.
  /// - Throws: An error if the notification request fails or if the peripheral disconnects.
  @discardableResult
  public func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic) async throws -> Bool {
    if await characteristic.isNotifying.current == enabled {
      return true
    }
    return try await withCheckedThrowingContinuation { continuation in
      if notifyCharacteristicValueContinuations[characteristic.uuid] == nil {
        notifyCharacteristicValueContinuations[characteristic.uuid] = []
      }
      notifyCharacteristicValueContinuations[characteristic.uuid]?.append(continuation)
      cbPeripheral.setNotifyValue(enabled, for: characteristic.characteristic)
    }
  }
}

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
