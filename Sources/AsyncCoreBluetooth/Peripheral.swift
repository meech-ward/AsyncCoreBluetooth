@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation

/// The possible states of a peripheral connection.
///
/// * Defaults to disconnected(nil)
/// * Calling connect() on the central manager will cause the connectionState to change to connecting
/// * After conencting, the device will change to connected or failedToConnect
/// * Calling disconnect() on the central manager will cause the connectionState to change to disconnecting
/// * After disconnecting, the device will change to disconnected(nil)
/// * If the device disconnects unexpectedly, the device will change straight from connected to disconnected(error)
public enum PeripheralConnectionState: Equatable, Sendable {
  case disconnected(CBError?)
  case connecting
  case connected
  case disconnecting
  case failedToConnect(CBError)
}

@Observable
@MainActor
public class PeripheralState {
  init(cbPeripheral: CBMPeripheral) {
    identifier = cbPeripheral.identifier
    name = cbPeripheral.name
  }

  public let identifier: UUID

  /// The name of the peripheral.
  ///
  /// This is a published property, acessable only on the main actor, so it can be easily used with swift UI.
  /// Example:
  /// ```swift
  ///  @ObservedObject var peripheral: Peripheral
  ///  var body: some View {
  ///    VStack {
  ///      Text("\(peripheral.name ?? "No Name")")
  ///
  /// ```
  public internal(set) var name: String?

  // MARK: - Peripheral Connection State

  /// The current Peripheral.ConnectionState state of this peripheral.
  ///
  /// This is a published property, acessable only on the main actor, so it can be easily used with swift UI.
  /// Example:
  /// ```swift
  ///  @ObservedObject var peripheral: Peripheral
  ///  var body: some View {
  ///    VStack {
  ///      Text("\(peripheral.name ?? "No Name")")
  ///      switch peripheral.connectionState {
  ///      case .connecting:
  ///        Text("Connecting...")
  ///      case .disconnected(let error):
  ///        Text("Disconnected \(error?.localizedDescription ?? "")")
  ///      case .connected:
  ///        Text("Connected")
  ///      case .disconnecting:
  ///        Text("Disconnecting")
  ///      case .failedToConnect(let error):
  ///        Text("Failed to connect \(error.localizedDescription)")
  ///      }
  ///    }
  ///    .task {
  ///      await centralManager.connect(peripheral)
  ///    }
  /// }
  /// ```
  public internal(set) var connectionState: PeripheralConnectionState = .disconnected(nil)

  /// A list of a peripheral’s discovered services.
  public var services: [Service]?
}

/// The Peripheral actor represents remote peripheral devices that your app discovers with a central manager.
///
/// Peripherals use UUIDs to identify themselves.
/// Peripherals may contain one or more services or provide useful information about their connected signal strength.
///
/// You use this actor to discover, explore, and interact with the services available on a remote peripheral that supports Bluetooth low energy.
/// A service encapsulates the way part of the device behaves. For example, one service of a heart rate monitor may be to expose heart rate data from a sensor.
/// Services themselves contain of characteristics or included services (references to other services). Characteristics provide further details about a peripheral’s service. For example, the heart rate service may contain multiple characteristics. One characteristic could describe the intended body location of the device’s heart rate sensor, and another characteristic could transmit the heart rate measurement data.
/// Finally, characteristics contain any number of descriptors that provide more information about the characteristic’s value, such as a human-readable description and a way to format the value.
///
/// You don’t create Peripheral instances directly. Instead, you receive them from the central manager when you discover, connect to, or retrieve connected peripherals.
public actor Peripheral {
  @MainActor
  public private(set) var state: PeripheralState!

  // MARK: - Peripheral Properties

  /// The underlying ``CBMPeripheral`` instance.
  ///
  /// Avoid using this if you can. It's been left public in case this library missed some functionality that is only available in the underlying ``CBMPeripheral``.
  public private(set) var cbPeripheral: CBMPeripheral

  //  var state: PeripheralState {
  //    cbPeripheral.state
  //  }

  /// The unique identifier associated with the peripheral.
  ///
  /// Acessable only on the main actor.
  public let identifier: UUID

  /// The name of the peripheral.
  ///
  /// This is a published property, acessable only on the main actor, so it can be easily used with swift UI.
  /// Example:
  /// ```swift
  ///  @ObservedObject var peripheral: Peripheral
  ///  var body: some View {
  ///    VStack {
  ///      Text("\(peripheral.name ?? "No Name")")
  ///
  /// ```
  public private(set) var name: String? {
    willSet {
      Task { @MainActor in
        state.name = newValue
      }
    }
  }

  /// An optional delegate for a more clasical implementation.
  ///
  /// The delegate methods will get called straight from the CBMPeripheral delegate without going through the Peripheral actor. Avoid using this if you can and just use async streams.
  /// However, if you really need to use the delegate, you can pass it in here. This will not effect the async streams.
  public var delegate: CBMPeripheralDelegate?
  private nonisolated lazy var peripheralDelegate = PeripheralDelegate(peripheral: self)

  // MARK: - Peripheral Connection State

  /// The current Peripheral.ConnectionState state of this peripheral.
  ///
  /// This is a published property, acessable only on the main actor, so it can be easily used with swift UI.
  /// Example:
  /// ```swift
  ///  @ObservedObject var peripheral: Peripheral
  ///  var body: some View {
  ///    VStack {
  ///      Text("\(peripheral.name ?? "No Name")")
  ///      switch peripheral.connectionState {
  ///      case .connecting:
  ///        Text("Connecting...")
  ///      case .disconnected(let error):
  ///        Text("Disconnected \(error?.localizedDescription ?? "")")
  ///      case .connected:
  ///        Text("Connected")
  ///      case .disconnecting:
  ///        Text("Disconnecting")
  ///      case .failedToConnect(let error):
  ///        Text("Failed to connect \(error.localizedDescription)")
  ///      }
  ///    }
  ///    .task {
  ///      await centralManager.connect(peripheral)
  ///    }
  /// }
  /// ```
  public internal(set) var connectionState: PeripheralConnectionState = .disconnected(nil) {
    willSet {
      Task { @MainActor in
        state.connectionState = newValue
      }
    }
  }

  func setConnectionState(_ state: PeripheralConnectionState) async {
    connectionState = state
  }

  // MARK: - Peripheral Creation

  private init(cbPeripheral: CBMPeripheral) async {
    self.cbPeripheral = cbPeripheral
    identifier = cbPeripheral.identifier
    name = cbPeripheral.name
    await MainActor.run {
      self.state = .init(cbPeripheral: cbPeripheral)
    }
    cbPeripheral.delegate = peripheralDelegate
  }

  // MARK: - Peripheral Creation and Caching

  static func getOrCreatePeripheral(cbPeripheral: CBMPeripheral) async -> Peripheral {
    if let peripheral = await PeripheralStore.shared.getPeripheral(for: cbPeripheral.identifier) {
      return peripheral
    } else {
      let peripheral = await Peripheral(cbPeripheral: cbPeripheral)
      await PeripheralStore.shared.store(peripheral, for: cbPeripheral.identifier)
      return peripheral
    }
  }

  static func getPeripheral(cbPeripheral: CBMPeripheral) async -> Peripheral? {
    await PeripheralStore.shared.getPeripheral(for: cbPeripheral.identifier)
  }

  static func getPeripheral(peripheralUUID: UUID) async -> Peripheral? {
    await PeripheralStore.shared.getPeripheral(for: peripheralUUID)
  }

  // MARK: - Discovering Services

  // https://developer.apple.com/documentation/corebluetooth/cbperipheral#1667320

  /// Discovers the specified services of the peripheral.
  // internally manage the state continuations
  var discoverServicesContinuations: [UUID: AsyncStream<CBMService>.Continuation] = [:]
  func setdDiscoverServicesContinuation(
    id: UUID, continuation: AsyncStream<CBMService>.Continuation?
  ) {
    discoverServicesContinuations[id] = continuation
  }

  var discoverServicesContinuation: CheckedContinuation<[Service], Never>? = nil
  public func discoverServices(_ serviceUUIDs: [CBUUID]?) async -> [Service] {
    return await withCheckedContinuation { continuation in
      discoverServicesContinuation = continuation
      cbPeripheral.discoverServices(serviceUUIDs)
    }
  }

  /// Discovers the specified included services of a previously-discovered service.
  public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: Service) {}

  /// A list of a peripheral’s discovered services.
  public var services: [Service]? {
    willSet {
      Task { @MainActor in
        state.services = newValue
      }
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
