import AsyncAlgorithms
@preconcurrency
import CoreBluetoothMock
import Foundation

/// This class wraps the `CBMCentralManager` class and provides an async interface for interacting with it.
///
/// You can initialize a ``CentralManager`` with optional parameters, but you probably don't need to pass in any of them. Just call `CentralManager()`.
/// Once you've created a ``CentralManager``, you'll need to call start before using any of the other methods. From there, it's very similar to using a `CBCentralManager`, but data is accessed using swift concurrency instead of delegate methods.
///
/// Example:
/// ```swift
/// import AsyncCoreBluetooth
///
/// let centralManager = CentralManager()
///
/// for await bleState in await centralManager.start() {
///   switch bleState {
///     case .unknown:
///       print("Unkown")
///     case .resetting:
///       print("Resetting")
///     case .unsupported:
///       print("Unsupported")
///     case .unauthorized:
///       print("Unauthorized")
///     case .poweredOff:
///       print("Powered Off")
///     case .poweredOn:
///       print("Powered On, ready to scan")
///       break
///   }
/// }
///
/// for await devices in try await centralManager.scanForPeripherals(withServices: []) {
///   print("Found device: \(device)")
/// }
/// ```
///

@Observable
public class CentralManagerState {
  var bleState: CentralManagerBLEState = .unknown
  var isScanning = false
}

public actor CentralManager {
  // A flag to force mocking also on physical device. Useful for testing.
  private let forceMock: Bool
  // An optional dispatch queue to be passed into CBMCentralManager. Probably unnessary since this thing is an actor and all outside method calls are going to be async.
  private let queue: DispatchQueue?
  // An optional `options` dictionary to be passed into CBMCentralManager.
  private let options: [String: Any]?

  // The internal delegate used to receive data from core data and emit that data using swift concurrency
  private lazy var centralManagerDelegate: CentralManagerDelegate = .init(centralManager: self)

  /// An optional delegate for a more clasical implementation.
  ///
  /// The delegate methods will get called straight from the CBMCentralManager delegate without going through the CentralManager actor. Avoid using this if you can and just use async streams.
  /// However, if you really need to use the delegate, you can pass it in here. This will not effect the async streams.
  public var delegate: CBMCentralManagerDelegate?

  /// The underlying ``CBMCentralManager`` instance.
  ///
  /// Avoid using this if you can. It's been left public in case this library missed some functionality that is only available in the underlying ``CBMCentralManager``.
  public lazy var centralManager: CBMCentralManager = CBMCentralManagerFactory.instance(delegate: centralManagerDelegate,
                                                                                        queue: queue,
                                                                                        options: options,
                                                                                        forceMock: forceMock)

  /// Initializes the central manager with optional parameters, but you probably don't need to pass in any of them. Just call `CentralManager()`
  ///
  /// - Parameters:
  ///   - delegate: An optional delegate for a more clasical implementation.
  ///   - queue: An optional dispatch queue for delegate callbacks.
  ///   - options: An optional dictionary containing options for the central manager.
  ///   - forceMock: A flag to determine whether to use a mock central manager.
  public init(delegate: CBMCentralManagerDelegate? = nil, queue: DispatchQueue? = nil, options: [String: Any]? = nil, forceMock: Bool = false) {
    self.delegate = delegate
    self.queue = queue
    self.options = options
    self.forceMock = forceMock
  }

  // MARK: - ble states (CentralManagerState)

  /// The device's current ``CentralManagerState``.
  ///
  /// This is a published property that you can use with SwiftUI to inform the user of the current state of BLE.
  ///
  /// Example Usage:
  /// ```swift
  ///  @StateObject var centralManager = CentralManager()
  ///  var body: some View {
  ///    VStack {
  ///      switch centralManager.bleState {
  ///      case .unknown:
  ///        Text("Unkown")
  ///      case .resetting:
  ///        Text("Resetting")
  ///      case .unsupported:
  ///        Text("Your device does not support Bluetooth")
  ///      case .unauthorized:
  ///        Text("Go into settings and authorize this app to use Bluetooth")
  ///      case .poweredOff:
  ///        Text("Turn your device's Bluetooth on")
  ///      case .poweredOn:
  ///        Text("Ready to go")
  ///      }
  ///    }
  ///  }
  /// ```
  @MainActor public internal(set) var centralManagerState = CentralManagerState()

  // internally manage the state continuations
  var stateContinuations: [UUID: AsyncStream<CentralManagerBLEState>.Continuation] = [:]
  func setStateContinuation(id: UUID, continuation: AsyncStream<CentralManagerBLEState>.Continuation?) {
    stateContinuations[id] = continuation
  }

  /// Starts the central manager and starts monitoring the `CentralManagerState` changes.
  ///
  /// This method is safe to call multiple times.
  ///
  /// This function retrieves the state from the underlying central manager and updates the published `bleState` property.
  /// You can also monitor the state changes using an async stream by calling the other `start() -> AsyncStream<CentralManagerState>` method
  public func start() async {
    let state = centralManagerBLEState()
    await MainActor.run {
      centralManagerState.bleState = state
    }
  }

  /// Starts the central manager and starts monitoring the `CentralManagerState` changes.
  ///
  /// This method is safe to call multiple times in order to check the potentially changing state of the underlying `CBCentralManager`.
  ///
  /// This function retrieves the state from the underlying central manager and updates the published `bleState` property.
  /// It also returns an `AsyncStream` that can be used to monitor changes to the BLE state using swift concurrency.
  /// Continuations are managed internally to track state changes.
  ///
  /// Example usage:
  /// ```swift
  /// for await state in centralManager.start() {
  ///   print("BLE state changed to: \(state)")
  /// }
  /// ```
  ///
  /// - Returns: an async stream that represents the up to date CentralManagerState
  public func start() -> AsyncStream<CentralManagerBLEState> {
    return AsyncStream { [weak self] continuation in
      guard let self = self else { return }

      let id = UUID()
      Task {
        await self.setStateContinuation(id: id, continuation: continuation)
        let state = await self.centralManagerBLEState()
        continuation.yield(state)
        await MainActor.run {
          self.centralManagerState.bleState = state
        }
      }

      continuation.onTermination = { @Sendable [weak self] _ in
        guard let self = self else { return }
        Task {
          await self.setStateContinuation(id: id, continuation: nil)
        }
      }
    }
  }

  // MARK: - Scanning or Stopping Scans of Peripherals

  // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager#1667498

  /// A flag to determine whether the central manager is currently scanning for peripherals.
  ///
  /// This is a published property, so you can use this in SwiftUI to inform the user of the current scanning state.
  ///
  /// Example Usage:
  /// ```swift
  /// @StateObject var centralManager = CentralManager()
  /// var body: some View {
  ///  VStack {
  ///   if centralManager.isScanning {
  ///      Text("Scanning")
  ///    } else {
  ///      Text("Not Scanning")
  ///    }
  ///  }
  /// }
  /// ```
  @Published @MainActor public private(set) var isScanning = false
  private(set) var internalIsScanning = false {
    willSet {
      Task {
        await MainActor.run {
          isScanning = newValue
        }
      }
    }
  }

  // internally manage the state continuations
  var scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?
  func setScanForPeripheralsContinuation(_ scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?) {
    self.scanForPeripheralsContinuation = scanForPeripheralsContinuation
  }

  /// Scans for peripherals that are advertising services.
  ///
  /// Scan will stop when task is canceled, so you don't need to call ``stopScan()``, but you do need to manage the task.
  /// All you need to do is cancel the parent task or break out of the loop when you're done scanning. That will cause the central manager's scan to stop.
  /// Optionally you can call ``stopScan()`` if you need to force it to stop without using swift concurrency. This will also cause the async stream to terminate.
  ///
  /// Example Usage:
  /// ```swift
  /// for await device in try await centralManager.scanForPeripherals(withServices: [...]) {
  ///  print("Found device: \(device)")
  /// // maybe add the device to a published set of devices you can present to the user
  /// // break out of the loop or cancel the parent task when you're done scanning
  /// }
  /// ```
  ///
  /// see https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipherals
  ///
  /// - Throws:
  ///   - `CentralManagerError.notPoweredOn` if the central manager is **not** in the poweredOn state.
  ///   - `CentralManagerError.alreadyScanning` if the central manager is already scanning.
  public func scanForPeripherals(withServices services: [CBMUUID]?, options _: [String: Any]? = nil) throws -> AsyncStream<Peripheral> {
    guard centralManager.state == .poweredOn else {
      throw CentralManagerError.notPoweredOn
    }
    guard !internalIsScanning else {
      throw CentralManagerError.alreadyScanning
    }
    internalIsScanning = true
    return AsyncStream { [weak self] continuation in
      guard let self = self else {
        return
      }
      
      Task { 
        await self.setScanForPeripheralsContinuation(continuation)
        await self.centralManager.scanForPeripherals(withServices: services)
      }

      continuation.onTermination = { @Sendable [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.stopScan()
        }
      }
    }
  }

  /// Scans for peripherals that are advertising services.
  /// Scan will stop when task is canceled, so no need to call `stopScan()`.
  ///
  /// ```swift
  /// for await device in try await centralManager.scanForPeripherals(withServices: [...]) {
  ///  print("Found device: \(device)")
  /// }
  /// ```
  ///
  /// see https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipherals
  public func scanForPeripherals(withServices services: [UUID], options: [String: Any]? = nil) throws -> AsyncStream<Peripheral> {
    return try scanForPeripherals(withServices: services.map { CBMUUID(nsuuid: $0) }, options: options)
  }

  /// Asks the central manager to stop scanning for peripherals.
  /// Avoid calling this directly. Instead, cancel the task returned by `scanForPeripherals(withServices:options:)`. That will automatically stop the scan.
  /// see https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518984-stopscan
  public func stopScan() {
    centralManager.stopScan()
    setScanForPeripheralsContinuation(nil)
    internalIsScanning = false
  }

  // MARK: - Establishing or Canceling Connections with Peripherals

  /// ## Establishing or Canceling Connections with Peripherals

  // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager#1667358

  typealias PeripheralConnectionContinuation = (peripheralUUID: UUID, continuation: AsyncStream<Peripheral.ConnectionState>.Continuation)
  var peripheralConnectionContinuations: [UUID: PeripheralConnectionContinuation] = [:]

  func setPeripheralConnectionContinuation(id: UUID, continuation: PeripheralConnectionContinuation?) {
    peripheralConnectionContinuations[id] = continuation
  }

  func getPeripheralConnectionContinuations(peripheralUUID: UUID) -> [PeripheralConnectionContinuation] {
    return peripheralConnectionContinuations.values.filter { $0.peripheralUUID == peripheralUUID }
  }

  func updatePeripheralConnectionState(peripheralUUID: UUID, state: Peripheral.ConnectionState) async {
    let peripheralConnectionContinuations = getPeripheralConnectionContinuations(peripheralUUID: peripheralUUID)
    // await peripheralConnectionContinuations.first?.peripheral.setConnectionState(state)
    await Peripheral.getPeripheral(peripheralUUID: peripheralUUID)?.setConnectionState(state)
    for peripheralConnectionContinuation in peripheralConnectionContinuations {
      peripheralConnectionContinuation.continuation.yield(state)
    }
  }

  /// Establishes a local connection to a peripheral.
  /// Canceling the task will NOT disconnect the peripheral. You must call `cancelPeripheralConnection(_:)` to disconnect.
  /// This allows you to keep "watching" for changed to device state even after a connection or disconnection.
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect
  @discardableResult public func connect(_ peripheral: Peripheral, options: [String: Any]? = nil) async throws -> AsyncStream<Peripheral.ConnectionState> {
    // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/peripheral_connection_options
    let currentConnectionState = await peripheral.connectionState
    guard currentConnectionState != .connected else {
      throw PeripheralConnectionError.alreadyConnected
    }
    guard currentConnectionState != .connecting else {
      throw PeripheralConnectionError.alreadyConnecting
    }

    await peripheral.setConnectionState(.connecting)
    let peripheralConnectionContinuations = getPeripheralConnectionContinuations(peripheralUUID: peripheral.identifier)
    peripheralConnectionContinuations.forEach { $0.continuation.yield(.connecting) }

    let stream = await connectionState(forPeripheral: peripheral)
    let cbPeripheral = await peripheral.cbPeripheral

    centralManager.connect(cbPeripheral, options: options)

    return stream
  }

  /// Get an async stream representing a peripheral's connection state.
  /// This is the same stream that you can get from `connect(_:)` and `cancelPeripheralConnection(_:)`.
  /// The connection state will be the same as peripheral.connectionState.
  public func connectionState(forPeripheral peripheral: Peripheral) async -> AsyncStream<Peripheral.ConnectionState> {
    let connectionState = await peripheral.connectionState
    let stream = AsyncStream { [weak self] continuation in
      guard let self = self else {
        return
      }

      let id = UUID()
      Task {
        await self.setPeripheralConnectionContinuation(id: id, continuation: (peripheral.identifier, continuation))
        // Do this twice after asynchronously adding it to the dictionary
        // That way we can await dropping the first value to know when this is ready
        await peripheral.setConnectionState(connectionState)
        continuation.yield(connectionState)
        continuation.yield(connectionState)
      }

      continuation.onTermination = { @Sendable [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.setPeripheralConnectionContinuation(id: id, continuation: nil)
        }
      }
    }
    for await _ in stream {
      break
    }
    return stream
  }

  /// Cancels an active or pending local connection to a peripheral.
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518952-cancelperipheralconnection
  @discardableResult public func cancelPeripheralConnection(_ peripheral: Peripheral) async throws -> AsyncStream<Peripheral.ConnectionState> {
    // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/peripheral_connection_options
    print("cancelPeripheralConnection")
    let currentConnectionState = await peripheral.connectionState
    if case .disconnected = currentConnectionState {
      throw PeripheralConnectionError.alreadyDisconnected
    }
    if case .failedToConnect = currentConnectionState {
      throw PeripheralConnectionError.failedToConnect
    }
    guard currentConnectionState != .disconnecting else {
      throw PeripheralConnectionError.alreadyDisconnecting
    }

    await peripheral.setConnectionState(.disconnecting)
    let peripheralConnectionContinuations = getPeripheralConnectionContinuations(peripheralUUID: peripheral.identifier)
    peripheralConnectionContinuations.forEach { $0.continuation.yield(.disconnecting) }

    let stream = await connectionState(forPeripheral: peripheral)

    let cbPeripheral = await peripheral.cbPeripheral
    centralManager.cancelPeripheralConnection(cbPeripheral)

    return stream
  }

  // MARK: - Retrieving Lists of Peripherals

  // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1519127-retrieveperipherals

  var retreivedPeripherals: [UUID: Peripheral] = [:]

  /// Returns a list of known peripherals by their identifiers.
  public func retrieveConnectedPeripherals(withServices services: [CBMUUID]) async -> [Peripheral] {
    let cbPeripherals = centralManager.retrieveConnectedPeripherals(withServices: services)
    var peripherals = [Peripheral]()
    for cbPeripheral in cbPeripherals {
      peripherals.append(await Peripheral.getOrCreatePeripheral(cbPeripheral: cbPeripheral))
    }
    return peripherals
  }

  /// Returns a list
  public func retrievePeripherals(withIdentifiers identifiers: [UUID]) async -> [Peripheral] {
    let cbPeripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)
    var peripherals = [Peripheral]()
    for cbPeripheral in cbPeripherals {
      peripherals.append(await Peripheral.getOrCreatePeripheral(cbPeripheral: cbPeripheral))
    }
    return peripherals
  }

  // MARK: - Inspecting Feature Support

  /// Returns a boolean value representing the support for the provided features.
  /// See:  https://developer.apple.com/documentation/corebluetooth/cbcentralmanager#3222461
  #if !os(macOS)
    public static func supports(_ features: CBMCentralManager.Feature) -> Bool {
      return CBMCentralManager.supports(features)
    }
  #endif

  // MARK: - Receiving Connection Events

  /// See: https://developer.apple.com/documentation/corebluetooth/cbcentralmanager#3222461
  func registerForConnectionEvents(options _: [CBMConnectionEventMatchingOption: Any]? = nil) {
    // Not implemented yet
  }
}

// MARK: - Internal Helpers

extension CentralManager {

  func centralManagerBLEState() -> CentralManagerBLEState {
    return centralManager.state
  }
}
