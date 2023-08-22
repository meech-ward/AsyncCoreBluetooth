@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class CentralManagerStateTests: XCTestCase, XCTestObservation {
  override static func setUp() {
    super.setUp()
    let peripheral = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate())
    CBMCentralManagerMock.simulatePeripherals([peripheral])
  }

  func test_initialState_unkown() async throws {
    CBMCentralManagerMock.simulateInitialState(.unknown)
    let centralManager = CentralManager(forceMock: true)
    await MainActor.run {
      let state = centralManager.bleState
      XCTAssertEqual(state, .unknown)
    }
    for await state in await centralManager.start() {
      XCTAssertEqual(state, .unknown)
      break
    }
  }

  func test_initialStateProperty_afterStart() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let centralManager = CentralManager(forceMock: true)
    await centralManager.start()
    await MainActor.run {
      let state = centralManager.bleState
      XCTAssertEqual(state, .poweredOn)
    }
  }
  
  func test_initialStateSequence_afterStart() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start().dropFirst(1) {
      XCTAssertEqual(state, .poweredOn)
      break
    }
  }

  func test_startWithAsyncSequence_removesSequenceOnTaskCompletion() async throws {
    let centralManager = CentralManager(forceMock: true)
    var continuations = await centralManager.stateContinuations
    XCTAssertEqual(continuations.count, 0)
    for await _ in await centralManager.start() {
      continuations = await centralManager.stateContinuations
      XCTAssertEqual(continuations.count, 1)
      break
    }
    // wait for the current tasks to finish
    try await Task.sleep(nanoseconds: 1)
    try await Task.sleep(nanoseconds: 1)
    continuations = await centralManager.stateContinuations
    XCTAssertEqual(continuations.count, 0)

    for await _ in await centralManager.start() {
      continuations = await centralManager.stateContinuations
      XCTAssertEqual(continuations.count, 1)
      break
    }
    // wait for the current tasks to finish
    try await Task.sleep(nanoseconds: 1)
    try await Task.sleep(nanoseconds: 1)
    continuations = await centralManager.stateContinuations
    XCTAssertEqual(continuations.count, 0)
  }
}
