@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class ConnectToNewDeviceTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  var mockPeripheralSuccess: CBMPeripheralSpec!
  var mockPeripheralFailure: CBMPeripheralSpec!
  var mockPeripheralSuccessDelegate: MockPeripheral.Delegate!
  var mockPeripheralFailureDelegate: MockPeripheral.Delegate!

  override func setUp() async throws {
    mockPeripheralSuccessDelegate = MockPeripheral.Delegate(peripheralDidReceiveConnectionRequestResult: .success(()))
    mockPeripheralFailureDelegate = MockPeripheral.Delegate(peripheralDidReceiveConnectionRequestResult: .failure(CBMError(.connectionFailed)))
    mockPeripheralSuccess = MockPeripheral.makeDevice(delegate: mockPeripheralSuccessDelegate)
    mockPeripheralFailure = MockPeripheral.makeDevice(delegate: mockPeripheralFailureDelegate)
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheralSuccess, mockPeripheralFailure])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start() {
      if state == .poweredOn {
        break
      }
    }
  }

  override func tearDown() {
    centralManager = nil
  }
}

// Initial disconnected and connecting states
extension ConnectToNewDeviceTests {
  func test_connectionState_startsAtDisconnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      XCTAssertEqual(connectionState, .disconnected(nil), "Expected connectionState to be disconnected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnected(nil), "Expected deviceConnectionState to be disconnected, got \(deviceConnectionState)")
      break
    }
  }

  func test_connectionState_changesToConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        try await centralManager.connect(device)
        i += 1
        continue
      }
      // stream state
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connecting, "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)")
      break
    }
  }

  func test_connectionState_startsAtDisconnected_andChangesToConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    // should start by being disconnected
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      XCTAssertEqual(connectionState, .disconnected(nil), "Expected connectionState to be disconnected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnected(nil), "Expected deviceConnectionState to be disconnected, got \(deviceConnectionState)")
      break
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connecting, "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)")
      break
    }
  }

  func test_connectWithStream_updatesStreamStateToConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates {
      // stream state
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connecting, "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)")
      break
    }
  }

  func test_initialConnectionStates_worksForMultipleListeners() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    @Sendable func assertConnectionStates(stream: AsyncStream<Peripheral.ConnectionState>) async {
      var i = 0
      for await connectionState in stream {
        let expectedState: Peripheral.ConnectionState = i == 0 ? .disconnected(nil) : .connecting
        i += 1

        XCTAssertEqual(connectionState, expectedState, "Expected connectionState to be \(expectedState), got \(connectionState)")

        if i == 2 {
          break
        }
      }
    }
    let stream1 = await centralManager.connectionState(forPeripheral: device)
    let stream2 = await centralManager.connectionState(forPeripheral: device)
    let stream3 = await centralManager.connectionState(forPeripheral: device)
    let connectionStates = try await centralManager.connect(device)
    await withTaskGroup(of: Void.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask {
        for await connectionState in connectionStates {
          // stream state
          XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")
          break
        }
      }
    }
  }
}

// Succesfull connected state
extension ConnectToNewDeviceTests {
  func test_successfulConnection_connectionState_changesToConnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        try await centralManager.connect(device)
        i += 1
        continue
      }
      if i == 1 {
        i += 1
        continue
      }
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connected, "Expected deviceConnectionState to be connected, got \(deviceConnectionState)")
      break
    }
  }

  func test_successfulConnection_connectionState_isConnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connected, "Expected deviceConnectionState to be connected, got \(deviceConnectionState)")
      break
    }
  }

  func test_successfulConnection_connectWithStream_isConnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connected, "Expected deviceConnectionState to be connected, got \(deviceConnectionState)")
      break
    }
  }

  func test_successfulConnection_initialConnectedState_worksForMultipleListeners() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    @Sendable func assertConnectionStates(stream: AsyncDropFirstSequence<AsyncStream<Peripheral.ConnectionState>>) async {
      for await connectionState in stream {
        let expectedState: Peripheral.ConnectionState = .connected
        XCTAssertEqual(connectionState, expectedState, "Expected connectionState to be \(expectedState), got \(connectionState)")
        break
      }
    }
    let stream1 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream2 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream3 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let connectionStates = try await centralManager.connect(device).dropFirst()
    await withTaskGroup(of: Void.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask { await assertConnectionStates(stream: connectionStates) }
    }
  }
}

// UnSuccesfull connected state
extension ConnectToNewDeviceTests {
  func assertConnectionStateIsConnectionFailed(_ connectionState: Peripheral.ConnectionState) {
    if case let .failedToConnect(err) = connectionState {
      XCTAssertEqual(err.code, CBMError.connectionFailed)
    } else {
      XCTFail("Unexpected connection state expected \(connectionState) to be connectionFailed")
    }
  }

  func test_unsuccessfulConnection_connectionState_changesToFailed() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        try await centralManager.connect(device)
        i += 1
        continue
      }
      if i == 1 {
        i += 1
        continue
      }
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }
  }

  func test_unsuccessfulConnection_connectionState_isFailed() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }
  }

  func test_unsuccessfulConnection_connectWithStream_isFailed() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }
  }

  func test_unsuccessfulConnection_canSuccesfullyConnectAfter() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }

    mockPeripheralFailureDelegate.peripheralDidReceiveConnectionRequestResult = .success(())

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connected, "Expected deviceConnectionState to be connected, got \(deviceConnectionState)")
      break
    }
  }

  func test_unsuccessfulConnection_initialConnectedState_worksForMultipleListeners() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    @Sendable func assertConnectionStates(stream: AsyncDropFirstSequence<AsyncStream<Peripheral.ConnectionState>>) async {
      for await connectionState in stream {
        assertConnectionStateIsConnectionFailed(connectionState)
        break
      }
    }
    let stream1 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream2 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream3 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let connectionStates = try await centralManager.connect(device).dropFirst()
    await withTaskGroup(of: Void.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask { await assertConnectionStates(stream: connectionStates) }
    }
  }
}

// Already connecting or connected
extension ConnectToNewDeviceTests {
  func test_connect_throws_whenCalledWhileConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      do {
        try await centralManager.connect(device)
        XCTFail("Didn't throw error")
      } catch {
        XCTAssertNotNil(error)
      }

      break
    }
  }

  func test_connect_throws_whenCalledWhileConnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    try await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      do {
        try await centralManager.connect(device)
        XCTFail("Didn't throw error")
      } catch {
        XCTAssertNotNil(error)
      }

      break
    }
  }
}

// func test_connect_serially_updatesDeviceState() async throws {
//   let devices = try await centralManager.scanForPeripherals(withServices: [UUIDs.Device.service])
//   guard let device = await devices.first(where: { $0.identifier == mockPeripheral.identifier }) else {
//     XCTFail("couldn't get device")
//     return
//   }

//   for await connectionState in try await device.connect().dropFirst(1) {
//     XCTAssertEqual(connectionState, .connected)

//     // Published connection state property
//     let deviceConnectionState = await device.connectionState
//     XCTAssertEqual(deviceConnectionState, .connected)
//     break
//   }

//   // next time connectionState is called, it should pick up where we left off
//   for await connectionState in await device.getConnectionState() {
//     XCTAssertEqual(connectionState, .connected)

//     // Published connection state property
//     let deviceConnectionState = await device.connectionState
//     XCTAssertEqual(deviceConnectionState, .connected)
//     break
//   }

//   mockPeripheral.simulateDisconnection(withError: CBMError(.peripheralDisconnected))

//   // next time device.connectionState is called, it should pick up where we left off and continue
//   for await connectionState in await device.getConnectionState().dropFirst(1) {
//     if case let .disconnected(err) = connectionState {
//       XCTAssertEqual(err!.code, CBMError.peripheralDisconnected)
//     } else {
//       XCTFail("Unexpected connection state \(connectionState.text()), expected disconnected")
//     }

//     // Published connection state property
//     let deviceConnectionState = await device.connectionState
//     if case let .disconnected(err) = deviceConnectionState {
//       XCTAssertEqual(err!.code, CBMError.peripheralDisconnected)
//     } else {
//       XCTFail("Unexpected connection state, expected disconnected")
//     }
//     break
//   }
// }

// func test_connect_concurrently_updatesDeviceState() async throws {
//   let devices = try await centralManager.scanForPeripherals(withServices: [UUIDs.Device.service])
//   guard let device = await devices.first(where: { $0.identifier == mockPeripheral.identifier }) else {
//     XCTFail("couldn't get device")
//     return
//   }

//   do {
//     try await withThrowingTaskGroup(of: Void.self) { group in
//       group.addTask {
//         _ = try await device.connect().dropFirst(1)
//       }

//       group.addTask {
//         _ = try await device.connect().dropFirst(1)
//       }

//       try await group.next()
//       try await group.next()
//     }
//     XCTFail("Didn't throw")
//   } catch {
//     print(error)
//     XCTAssertNotNil(error)
//   }
// }

// func test_getConnectionState_worksForMultipleListeners() {}
