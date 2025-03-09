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
      let state = centralManager.bleState.current
      #expect(state == .unknown)
    }
    for await state in await centralManager.start() {
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
    let state = await centralManager.bleState.current

    #expect(state == .poweredOn)
    await MainActor.run {
      let state = centralManager.bleState.current
      #expect(state == .poweredOn)
    }
  }

  @Test("Initial state sequence after start")
  func test_initialStateSequence_afterStart() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start().dropFirst(1) {
      #expect(state == .poweredOn)
      break
    }
  }
}
