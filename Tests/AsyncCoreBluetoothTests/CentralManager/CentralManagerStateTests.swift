import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct CentralManagerStateTests {
  init() {
    let peripheral = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate())
    CBMCentralManagerMock.simulatePeripherals([peripheral])
  }

  @Test("Initial state defaults to unknown")
  func test_initialState_unkown() async throws {
    CBMCentralManagerMock.simulateInitialState(.unknown)
    let centralManager = CentralManager(forceMock: true)
    await MainActor.run {
      let state = centralManager.state.bleState
      #expect(state == .unknown)
    }
    for await state in await centralManager.startStream() {
      #expect(state == .unknown)
      break
    }
  }

  @Test("Initial state property after start")
  func test_initialStateProperty_afterStart() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let centralManager = CentralManager(forceMock: true)
    await centralManager.start()
    // allow the delegate to set the new property
    try await Task.sleep(nanoseconds: 100000)
    let state = await centralManager.bleState

    #expect(state == .poweredOn)
    await MainActor.run {
      let state = centralManager.state.bleState
      #expect(state == .poweredOn)
    }
  }

  @Test("Initial state sequence after start")
  func test_initialStateSequence_afterStart() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.startStream().dropFirst(1) {
      #expect(state == .poweredOn)
      break
    }
  }

  @Test("Start with AsyncSequence removes the async sequence on task completion")
  func test_startWithAsyncSequence_removesSequenceOnTaskCompletion() async throws {
    let centralManager = CentralManager(forceMock: true)
    var continuations = await centralManager.stateContinuations
    #expect(continuations.count == 0)
    for await _ in await centralManager.startStream() {
      continuations = await centralManager.stateContinuations
      #expect(continuations.count == 1)
      break
    }
    // wait for the current tasks to finish
    try await Task.sleep(nanoseconds: 10)
    try await Task.sleep(nanoseconds: 10)
    continuations = await centralManager.stateContinuations
    #expect(continuations.count == 0)

    for await _ in await centralManager.startStream() {
      continuations = await centralManager.stateContinuations
      #expect(continuations.count == 1)
      break
    }
    // wait for the current tasks to finish
    try await Task.sleep(nanoseconds: 10)
    try await Task.sleep(nanoseconds: 10)
    continuations = await centralManager.stateContinuations
    #expect(continuations.count == 0)
  }
}
