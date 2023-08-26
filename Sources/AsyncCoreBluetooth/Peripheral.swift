import CoreBluetooth
import CoreBluetoothMock
import Foundation

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
public actor Peripheral: ObservableObject {
  
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
  @MainActor public let identifier: UUID

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
  @MainActor @Published public private(set) var name: String?

  /// An optional delegate for a more clasical implementation.
  ///
  /// The delegate methods will get called straight from the CBMPeripheral delegate without going through the Peripheral actor. Avoid using this if you can and just use async streams.
  /// However, if you really need to use the delegate, you can pass it in here. This will not effect the async streams.
  public var delegate: CBMPeripheralDelegate?

  // MARK: - Peripheral Connection State

  /// The possible states of a peripheral connection.
  ///
  /// * Defaults to disconnected(nil)
  /// * Calling connect() on the central manager will cause the connectionState to change to connecting
  /// * After conencting, the device will change to connected or failedToConnect
  /// * Calling disconnect() on the central manager will cause the connectionState to change to disconnecting
  /// * After disconnecting, the device will change to disconnected(nil)
  /// * If the device disconnects unexpectedly, the device will change straight from connected to disconnected(error)
  public enum ConnectionState: Equatable {
    case disconnected(CBError?)
    case connecting
    case connected
    case disconnecting
    case failedToConnect(CBError)
  }

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
  @MainActor @Published public internal(set) var connectionState: ConnectionState = .disconnected(nil)

  func setConnectionState(_ state: ConnectionState) async {
    await MainActor.run {
      connectionState = state
    }
  }

  // MARK: - Peripheral Creation and Caching

  // A cache of peripherals to avoid creating new ones every time
  @MainActor private(set) static var storedPeripherals: [UUID: Peripheral] = [:]

  @MainActor static func getOrCreatePeripheral(cbPeripheral: CBMPeripheral) -> Peripheral {
    if let peripheral = storedPeripherals[cbPeripheral.identifier] {
      return peripheral
    } else {
      let peripheral = Peripheral(cbPeripheral: cbPeripheral)
      storedPeripherals[cbPeripheral.identifier] = peripheral
      return peripheral
    }
  }

  @MainActor static func getPeripheral(cbPeripheral: CBMPeripheral) -> Peripheral? {
    storedPeripherals[cbPeripheral.identifier]
  }

  @MainActor static func getPeripheral(peripheralUUID: UUID) -> Peripheral? {
    storedPeripherals[peripheralUUID]
  }

  @MainActor private init(cbPeripheral: CBMPeripheral) {
    self.cbPeripheral = cbPeripheral
    identifier = cbPeripheral.identifier
    name = cbPeripheral.name
  }

  var services: [CBMService]?
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
