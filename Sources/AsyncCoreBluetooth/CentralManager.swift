import CoreBluetoothMock
import Foundation

public actor CentralManager: ObservableObject {
  public enum CentralManagerError: Error {
    case alreadyScanning
  }

  /// A flag to force mocking also on physical device. Useful for testing.
  private let forceMock: Bool
  /// An optional delegate for a more clasical implementationl. These will get sent straight from the CBMCentralManager delegate without going through the CentralManager actor. Avoid using this if you can.
  let delegate: CBMCentralManagerDelegate?
  /// An optional dispatch queue to be passed into CBMCentralManager. Probably unnessary since this thing is an actor and all outside method calls are going to be async.
  private let queue: DispatchQueue?
  /// An optional `options` dictionary to be passed into CBMCentralManager.
  private let options: [String: Any]?

  private lazy var centralManagerDelegate: CentralManagerDelegate = .init(centralManager: self)

  /// The underlying CBMCentralManager instance.
  public lazy var centralManager: CBMCentralManager = CBMCentralManagerFactory.instance(delegate: centralManagerDelegate,
                                                                                        queue: queue,
                                                                                        options: options,
                                                                                        forceMock: forceMock)

  /// Initializes the central manager with optional parameters.
  ///
  /// - Parameters:
  ///   - delegate: An optional delegate for handling callbacks.
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

  @Published @MainActor public var bleState: CentralManagerState = .unknown

  /// Starts the central manager and sets the BLE state.
  ///
  /// This function retrieves the state from the underlying central manager and updates the published `bleState` property.
  public func start() async {
    let state = centralManager.state
    await MainActor.run {
      bleState = state
    }
  }

  var stateContinuations: [UUID: AsyncStream<CentralManagerState>.Continuation] = [:]

  func setStateContinuation(id: UUID, continuation: AsyncStream<CentralManagerState>.Continuation?) {
    stateContinuations[id] = continuation
  }

  /// Starts monitoring BLE state changes and returns an `AsyncStream`.
  /// This method is safe to call multiple times in order to check the potentially changing state of the underlying `CBCentralManager`.
  ///
  /// This function returns an `AsyncStream` that can be used to monitor changes to the BLE state.
  /// Continuations are managed internally to track state changes.
  ///
  /// Example usage:
  /// ```swift
  /// for await state in centralManager.start() {
  ///   print("BLE state changed to: \(state)")
  /// }
  /// ```
  public func start() -> AsyncStream<CentralManagerState> {
    return AsyncStream { [weak self] continuation in
      guard let self = self else { return }

      let id = UUID()
      Task {
        await self.setStateContinuation(id: id, continuation: continuation)
        await continuation.yield(self.centralManager.state)
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

  var scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?
  func setScanForPeripheralsContinuation(_ scanForPeripheralsContinuation: AsyncStream<Peripheral>.Continuation?) {
    self.scanForPeripheralsContinuation = scanForPeripheralsContinuation
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
  public func scanForPeripherals(withServices services: [CBMUUID]?, options _: [String: Any]? = nil) throws -> AsyncStream<Peripheral> {
    guard !internalIsScanning else {
      print("Already scanning, stop the scanning task before scanning again")
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

}
