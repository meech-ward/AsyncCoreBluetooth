import CoreBluetoothMock
import Foundation

public enum CentralManagerError: Error {
  case alreadyScanning
}

public actor CentralManager: ObservableObject {
  private let forceMock: Bool
  /// An optional delegate for a more clasical implementationl. These will get sent straight from the CBMCentralManager delegate without going through the CentralManager actor. Avoid using this if you can.
  let delegate: CBMCentralManagerDelegate?
  private let queue: DispatchQueue?
  private let options: [String: Any]?

  private lazy var centralManagerDelegate: CentralManagerDelegate = .init(centralManager: self)

  private lazy var centralManager: CBMCentralManager = CBMCentralManagerFactory.instance(delegate: centralManagerDelegate,
                                                                                         queue: queue,
                                                                                         options: options,
                                                                                         forceMock: forceMock)

  public init(delegate: CBMCentralManagerDelegate? = nil, queue: DispatchQueue? = nil, options: [String: Any]? = nil, forceMock: Bool = false) {
    self.delegate = delegate
    self.queue = queue
    self.options = options
    self.forceMock = forceMock
  }

  // MARK: - ble states (CBMManagerState)

  @Published @MainActor public var bleState: CBMManagerState = .unknown

  public func start() async {
    let state = centralManager.state
    await MainActor.run {
      bleState = state
    }
  }

  var stateContinuations: [UUID: AsyncStream<CBMManagerState>.Continuation] = [:]

  func addNewStateContinuation(id: UUID, continuation: AsyncStream<CBMManagerState>.Continuation) {
    stateContinuations[id] = continuation
  }

  func removeStateContinuation(id: UUID) {
    stateContinuations[id] = nil
  }

  public func start() -> AsyncStream<CBMManagerState> {
    return AsyncStream { [weak self] continuation in
      guard let self = self else { return }

      let id = UUID()
      Task {
        await self.addNewStateContinuation(id: id, continuation: continuation)
        await continuation.yield(self.centralManager.state)
      }

      continuation.onTermination = { @Sendable [weak self] _ in
        guard let self = self else { return }
        Task {
          await self.removeStateContinuation(id: id)
        }
      }
    }
  }
}
