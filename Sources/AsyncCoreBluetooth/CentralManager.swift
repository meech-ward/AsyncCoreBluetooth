import AsyncObservable
@preconcurrency import CoreBluetooth
// import AsyncAlgorithms
@preconcurrency import CoreBluetoothMock
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

  /// The underlying CBMCentralManager instance.
  ///
  /// Avoid using this if you can. It's been left public in case this library missed some functionality that is only available in the underlying CBMCentralManager.
  public lazy var centralManager: CBMCentralManager = CBMCentralManagerFactory.instance(
    delegate: centralManagerDelegate,
    queue: queue,
    options: options,
    forceMock: forceMock
  )

  /// The current Bluetooth state as an observable property.
  ///
  /// This property can be observed using AsyncSequence to monitor changes to the Bluetooth state.
  /// ```swift
  /// Task {
  ///   for await state in centralManager.bleState {
  ///     print("BLE state changed to: \(state)")
  ///   }
  /// }
  /// ```
  @MainActor
  let _bleState: AsyncObservable<CBMManagerState> = .init(.unknown)
  @MainActor
  public var bleState: some AsyncObservableReadOnly<CBMManagerState> { _bleState }

  /// Indicates whether the central manager is currently scanning for peripherals.
  ///
  /// This property can be observed using AsyncSequence to monitor changes to the scanning state.
  /// ```swift
  /// Task {
  ///   for await isScanning in centralManager.isScanning {
  ///     print("Scanning state changed to: \(isScanning)")
  ///   }
  /// }
  /// ```
  @MainActor
  let _isScanning: AsyncObservable<Bool> = .init(false)
  @MainActor
  public var isScanning: some AsyncObservableReadOnly<Bool> { _isScanning }

  /// Initializes the central manager with optional parameters, but you probably don't need to pass in any of them. Just call `CentralManager()`
  ///
  /// - Parameters:
  ///   - delegate: An optional delegate for a more clasical implementation.
  ///   - queue: An optional dispatch queue for delegate callbacks.
  ///   - options: An optional dictionary containing options for the central manager.
  ///   - forceMock: A flag to determine whether to use a mock central manager.
  public init(
    delegate: CBMCentralManagerDelegate? = nil,
    queue: DispatchQueue? = nil,
    options: [String: Any]? = nil,
    forceMock: Bool = false
  ) {
    self.delegate = delegate
    self.queue = queue
    self.options = options
    self.forceMock = forceMock
  }

  // MARK: - ble states (CentralManagerState)

  /// Starts the central manager and starts monitoring the `CentralManagerState` changes.
  ///
  /// This method is safe to call multiple times.
  ///
  /// This function retrieves the state from the underlying central manager and updates the published `bleState` property.
  /// You can also monitor the state changes using an async stream by calling the other `start() -> AsyncStream<CentralManagerState>` method
  ///
  /// Example usage:
  /// ```swift
  /// for await state in await centralManager.start() {
  ///   print("BLE state changed to: \(state)")
  /// }
  /// ```
  ///
  /// or
  ///
  /// ```swift
  /// Task {
  ///   for await state in centralManager.bleState {
  ///     print("BLE state changed to: \(state)")
  ///   }
  /// }
  /// centralManager.start()
  /// ```
  @discardableResult
  public func start() -> StreamOf<CBMManagerState> {
    // because it's lazy, this will also trigger the central being started
    _bleState.update(centralManager.state)
    return _bleState.stream
  }

  // MARK: - Scanning or Stopping Scans of Peripherals

  // internally manage the scanForPeripheralsContinuation continuations
  var scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?
  func setScanForPeripheralsContinuation(
    _ scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?
  ) {
    self.scanForPeripheralsContinuation = scanForPeripheralsContinuation
  }

  /// A collection of peripherals that have been discovered during scanning.
  ///
  /// This property can be observed using AsyncSequence to monitor newly discovered peripherals.
  /// ```swift
  /// Task {
  ///   for await peripherals in centralManager.peripheralsScanned {
  ///     print("Updated peripherals list: \(peripherals.map { $0.name ?? "Unknown" })")
  ///   }
  /// }
  /// ```
  @MainActor
  let _peripheralsScanned: AsyncObservable<[Peripheral]> = .init([])
  @MainActor
  public var peripheralsScanned: some AsyncObservableReadOnly<[Peripheral]> { _peripheralsScanned }

  // so we don't handle the same peripheral multiple times
  private var _peripheralsScannedIds: Set<UUID> = []
  internal func clearPeripheralsScanned() {
    _peripheralsScannedIds.removeAll()
    _peripheralsScanned.update([])
  }
  internal func addPeripheralsScannedId(id: UUID) -> Bool {
    if _peripheralsScannedIds.contains(id) {
      return false
    }
    _peripheralsScannedIds.insert(id)
    return true
  }

  private var servicesToScanFor: [CBUUID]?

  /// Starts scanning for peripherals that are advertising services and returns an AsyncStream of discovered peripherals.
  ///
  /// This method uses Swift concurrency to handle the scan lifecycle. The scan will automatically stop when:
  /// - The task is canceled
  /// - You break out of the loop iterating through the AsyncStream
  /// - The stream is terminated for any other reason
  ///
  /// You do NOT need to manually call ``stopScan()`` when using this method, as the scan is automatically
  /// stopped when the stream terminates.
  ///
  /// Example Usage:
  /// ```swift
  /// do {
  ///   for await device in try await centralManager.scanForPeripheralsStream(withServices: [...]) {
  ///     print("Found device: \(device)")
  ///     // maybe add the device to a published set of devices you can present to the user
  ///     // break out of the loop or cancel the parent task when you're done scanning
  ///   }
  ///   // Scan automatically stops when the loop exits or task is canceled
  /// } catch {
  ///   print("Error scanning: \(error)")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - services: An array of service UUIDs to scan for, or nil to scan for all services.
  ///   - options: An optional dictionary specifying options for the scan.
  /// - Returns: An AsyncStream providing discovered peripherals as they are found.
  /// - Throws:
  ///   - `CentralManagerError.notPoweredOn` if the central manager is **not** in the poweredOn state.
  ///   - `CentralManagerError.alreadyScanning` if the central manager is already scanning.
  ///
  public func scanForPeripheralsStream(withServices services: [CBUUID]?, options _: [String: Any]? = nil) throws -> AsyncStream<Peripheral> {
    guard centralManager.state == .poweredOn else {
      throw CentralManagerError.notPoweredOn
    }
    guard !_isScanning.current else {
      throw CentralManagerError.alreadyScanning
    }
    servicesToScanFor = services
    _isScanning.update(true)
    clearPeripheralsScanned()
    return AsyncStream { [weak self] continuation in
      guard let self = self else {
        return
      }
      Task {
        await self.setScanForPeripheralsContinuation(continuation)
        await self.centralManager.scanForPeripherals(withServices: await self.servicesToScanFor)
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

  /// Starts scanning for peripherals that are advertising services.
  ///
  /// IMPORTANT: Unlike the stream version, this method starts scanning but does NOT automatically stop.
  /// You MUST explicitly call ``stopScan()`` when you want to stop scanning.
  ///
  /// Example Usage:
  /// ```swift
  /// try centralManager.scanForPeripherals(withServices: [...])
  /// // Do something with scanned peripherals
  /// // ...
  /// // When finished, manually stop the scan
  /// centralManager.stopScan()
  /// ```
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipherals
  ///
  /// - Throws:
  ///   - `CentralManagerError.notPoweredOn` if the central manager is **not** in the poweredOn state.
  ///   - `CentralManagerError.alreadyScanning` if the central manager is already scanning.
  ///
  public func scanForPeripherals(withServices services: [CBUUID]?, options _: [String: Any]? = nil) throws {
    guard centralManager.state == .poweredOn else {
      throw CentralManagerError.notPoweredOn
    }
    guard !_isScanning.current else {
      throw CentralManagerError.alreadyScanning
    }
    servicesToScanFor = services
    _isScanning.update(true)
    clearPeripheralsScanned()
    centralManager.scanForPeripherals(withServices: services)
  }

  /// Starts scanning for peripherals that are advertising services, using UUID identifiers.
  ///
  /// IMPORTANT: Unlike the stream version, this method starts scanning but does NOT automatically stop.
  /// You MUST explicitly call ``stopScan()`` when you want to stop scanning.
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipherals
  ///
  /// - Throws:
  ///   - `CentralManagerError.notPoweredOn` if the central manager is **not** in the poweredOn state.
  ///   - `CentralManagerError.alreadyScanning` if the central manager is already scanning.
  ///
  public func scanForPeripherals(withServices services: [UUID], options: [String: Any]? = nil) throws {
    try scanForPeripherals(withServices: services.map { CBUUID(nsuuid: $0) }, options: options)
  }

  /// Scans for peripherals that are advertising services and returns an AsyncStream of discovered peripherals.
  ///
  /// This method uses Swift concurrency to handle the scan lifecycle. The scan will automatically stop when:
  /// - The task is canceled
  /// - You break out of the loop iterating through the AsyncStream
  /// - The stream is terminated for any other reason
  ///
  /// You do NOT need to manually call ``stopScan()`` when using this method, as the scan is automatically
  /// stopped when the stream terminates.
  ///
  /// Example Usage:
  /// ```swift
  /// for await device in try await centralManager.scanForPeripheralsStream(withServices: [...]) {
  ///   print("Found device: \(device)")
  ///   // Process discovered peripherals
  /// }
  /// // Scan automatically stops when the loop exits or task is canceled
  /// ```
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipherals
  ///
  /// - Throws:
  ///   - `CentralManagerError.notPoweredOn` if the central manager is **not** in the poweredOn state.
  ///   - `CentralManagerError.alreadyScanning` if the central manager is already scanning.
  ///
  public func scanForPeripheralsStream(withServices services: [UUID], options: [String: Any]? = nil) throws -> AsyncStream<Peripheral> {
    return try scanForPeripheralsStream(withServices: services.map { CBUUID(nsuuid: $0) }, options: options)
  }

  /// Asks the central manager to stop scanning for peripherals.
  ///
  /// This method should be called to manually stop a scan started with ``scanForPeripherals(withServices:options:)``.
  ///
  /// NOTE: You typically DON'T need to call this method when using ``scanForPeripheralsStream(withServices:options:)``,
  /// as that method automatically stops scanning when the returned AsyncStream is terminated
  /// (by breaking out of the loop or canceling the task).
  ///
  /// See https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518984-stopscan
  public func stopScan() {
    centralManager.stopScan()
    setScanForPeripheralsContinuation(nil)
    _isScanning.update(false)
  }

  // MARK: - Establishing or Canceling Connections with Peripherals

  /// ## Establishing or Canceling Connections with Peripherals

  // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager#1667358

  func updatePeripheralConnectionState(peripheralUUID: UUID, state: PeripheralConnectionState) async {
    let peripheral = await Peripheral.getPeripheral(peripheralUUID: peripheralUUID)
    await peripheral?.setConnectionState(state)
  }

  /// Establishes a local connection to a peripheral.
  ///
  /// This method attempts to connect to the specified peripheral and returns an AsyncStream that provides
  /// updates about the connection state. The stream will continue to emit updates even after the peripheral
  /// is connected, allowing you to monitor disconnection events.
  ///
  /// Important: Canceling the task will NOT disconnect the peripheral. You must call ``cancelPeripheralConnection(_:)`` 
  /// to disconnect. This allows you to keep monitoring for changes to device state even after a connection or disconnection.
  ///
  /// Example Usage:
  /// ```swift
  /// let connectionStream = await centralManager.connect(peripheral)
  /// for await connectionState in connectionStream {
  ///   switch connectionState {
  ///   case .connected:
  ///     print("Connected to peripheral")
  ///     // Discover services, characteristics, etc.
  ///   case .disconnected(let error):
  ///     if let error = error {
  ///       print("Disconnected with error: \(error)")
  ///     } else {
  ///       print("Disconnected normally")
  ///     }
  ///     break
  ///   case .connecting:
  ///     print("Connecting...")
  ///   case .disconnecting:
  ///     print("Disconnecting...")
  ///   case .failedToConnect(let error):
  ///     print("Failed to connect: \(error)")
  ///     break
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - peripheral: The peripheral to connect to.
  ///   - options: An optional dictionary specifying connection options.
  /// - Returns: An AsyncStream providing updates about the connection state.
  @discardableResult public func connect(_ peripheral: Peripheral, options: [String: Any]? = nil) async -> StreamOf<PeripheralConnectionState> {
    // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/peripheral_connection_options
    let currentConnectionState = await peripheral.connectionState.current
    guard currentConnectionState != .connected else {
      return await peripheral.connectionState.stream
    }
    guard currentConnectionState != .connecting else {
      return await peripheral.connectionState.stream
    }

    await peripheral.setConnectionState(.connecting)

    let stream = await peripheral.connectionState.stream
    let cbPeripheral = await peripheral.cbPeripheral

    centralManager.connect(cbPeripheral, options: options)

    return stream
  }

  /// Cancels an active or pending local connection to a peripheral.
  ///
  /// This method attempts to disconnect from the specified peripheral and returns an AsyncStream that provides
  /// updates about the disconnection process. The stream will emit a `.disconnecting` state followed by a 
  /// `.disconnected` state when the disconnection completes.
  ///
  /// Example Usage:
  /// ```swift
  /// let disconnectionStream = await centralManager.cancelPeripheralConnection(peripheral)
  /// for await connectionState in disconnectionStream {
  ///   switch connectionState {
  ///   case .disconnected(let error):
  ///     if let error = error {
  ///       print("Disconnected with error: \(error)")
  ///     } else {
  ///       print("Disconnected successfully")
  ///     }
  ///     break
  ///   case .disconnecting:
  ///     print("Disconnecting...")
  ///   default:
  ///     print("Unexpected state: \(connectionState)")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter peripheral: The peripheral to disconnect from.
  /// - Returns: An AsyncStream providing updates about the disconnection process.
  @discardableResult public func cancelPeripheralConnection(_ peripheral: Peripheral) async -> StreamOf<PeripheralConnectionState> {
    // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/peripheral_connection_options
    let currentConnectionState = await peripheral.connectionState.current
    if case .disconnected = currentConnectionState {
      return await peripheral.connectionState.stream
    }
    if case .failedToConnect = currentConnectionState {
      return await peripheral.connectionState.stream
    }
    guard currentConnectionState != .disconnecting else {
      return await peripheral.connectionState.stream
    }

    await peripheral.setConnectionState(.disconnecting)

    let stream = await peripheral.connectionState.stream

    let cbPeripheral = await peripheral.cbPeripheral
    centralManager.cancelPeripheralConnection(cbPeripheral)

    return stream
  }

  // MARK: - Retrieving Lists of Peripherals

  // https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1519127-retrieveperipherals

  var retreivedPeripherals: [UUID: Peripheral] = [:]

  /// Returns a list of known peripherals that are currently connected to the system and match the specified services.
  ///
  /// This method searches the system for connected peripherals that are advertising the specified services.
  /// It can be used to find peripherals that were connected by a different app or process.
  ///
  /// Example Usage:
  /// ```swift
  /// let heartRateServiceUUID = CBUUID(string: "180D")
  /// let connectedHeartRateMonitors = await centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
  /// for monitor in connectedHeartRateMonitors {
  ///   print("Found connected heart rate monitor: \(monitor.name ?? "Unknown")")
  /// }
  /// ```
  ///
  /// - Parameter services: An array of service UUIDs to search for.
  /// - Returns: An array of peripherals that are connected to the system and match the specified services.
  public func retrieveConnectedPeripherals(withServices services: [CBUUID]) async -> [Peripheral] {
    let cbPeripherals = centralManager.retrieveConnectedPeripherals(withServices: services)
    var peripherals = [Peripheral]()
    for cbPeripheral in cbPeripherals {
      if let peripheral = await Peripheral.getPeripheral(cbPeripheral: cbPeripheral) {
        print("got connected peripheral \(ObjectIdentifier(peripheral))")
        peripherals.append(peripheral)
        continue
      }
      let peripheral = await Peripheral.createPeripheral(cbPeripheral: cbPeripheral)
      print("created connected peripheral \(ObjectIdentifier(peripheral))")
      peripherals.append(peripheral)
    }
    return peripherals
  }

  /// Returns a list of peripherals that CoreBluetooth has previously discovered.
  ///
  /// This method retrieves peripherals that were previously discovered by CoreBluetooth
  /// and match the specified identifiers. The peripherals don't need to be currently connected.
  ///
  /// Example Usage:
  /// ```swift
  /// // Using UUIDs that were previously stored from discovered peripherals
  /// let savedPeripheralIDs: [UUID] = loadSavedPeripheralIdentifiers()
  /// let peripherals = await centralManager.retrievePeripherals(withIdentifiers: savedPeripheralIDs)
  /// for peripheral in peripherals {
  ///   print("Retrieved peripheral: \(peripheral.name ?? "Unknown")")
  /// }
  /// ```
  ///
  /// - Parameter identifiers: An array of UUIDs identifying the peripherals to retrieve.
  /// - Returns: An array of peripherals matching the specified identifiers.
  public func retrievePeripherals(withIdentifiers identifiers: [UUID]) async -> [Peripheral] {
    let cbPeripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)
    var peripherals = [Peripheral]()
    for cbPeripheral in cbPeripherals {
      if let peripheral = await Peripheral.getPeripheral(cbPeripheral: cbPeripheral) {
        print("got peripheral \(ObjectIdentifier(peripheral))")
        peripherals.append(peripheral)
        continue
      }
      let peripheral = await Peripheral.createPeripheral(cbPeripheral: cbPeripheral)
      peripherals.append(peripheral)
      print("created peripheral \(ObjectIdentifier(peripheral))")

    }
    return peripherals
  }

  /// Returns a single peripheral that CoreBluetooth has previously discovered with the specified identifier.
  ///
  /// This method is a convenience wrapper around `retrievePeripherals(withIdentifiers:)` for retrieving a single peripheral.
  ///
  /// Example Usage:
  /// ```swift
  /// if let peripheral = await centralManager.retrievePeripheral(withIdentifier: savedUUID) {
  ///   print("Retrieved peripheral: \(peripheral.name ?? "Unknown")")
  ///   await centralManager.connect(peripheral)
  /// } else {
  ///   print("Peripheral not found")
  /// }
  /// ```
  ///
  /// - Parameter identifier: A UUID identifying the peripheral to retrieve.
  /// - Returns: The peripheral matching the specified identifier, or nil if not found.
  public func retrievePeripheral(withIdentifier identifier: UUID) async -> Peripheral? {
    let peripherals = await retrievePeripherals(withIdentifiers: [identifier])
    return peripherals.first
  }

  // MARK: - Inspecting Feature Support

  /// Returns a boolean value representing the support for the provided features.
  ///
  /// Use this method to check if specific Bluetooth features are supported on the current device.
  ///
  /// Example Usage:
  /// ```swift
  /// #if !os(macOS)
  /// if CentralManager.supports(.extendedScanAndConnect) {
  ///   print("This device supports extended scan and connect")
  /// }
  /// #endif
  /// ```
  ///
  /// - Parameter features: The features to check for support.
  /// - Returns: A boolean value indicating whether the specified features are supported.
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
