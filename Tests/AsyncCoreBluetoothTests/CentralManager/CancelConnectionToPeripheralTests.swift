import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct CancelConnectionToPeripheralTests {
  var centralManager: CentralManager!
  var mockPeripheralSuccess: CBMPeripheralSpec!
  var mockPeripheralFailure: CBMPeripheralSpec!
  var mockPeripheralSuccessDelegate: MockPeripheral.Delegate!
  var mockPeripheralFailureDelegate: MockPeripheral.Delegate!

  init() async throws {
    mockPeripheralSuccessDelegate = MockPeripheral.Delegate(
      peripheralDidReceiveConnectionRequestResult: .success(()))
    mockPeripheralFailureDelegate = MockPeripheral.Delegate(
      peripheralDidReceiveConnectionRequestResult: .failure(CBError(.connectionFailed)))
    mockPeripheralSuccess = MockPeripheral.makeDevice(delegate: mockPeripheralSuccessDelegate)
    mockPeripheralFailure = MockPeripheral.makeDevice(delegate: mockPeripheralFailureDelegate)
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheralSuccess, mockPeripheralFailure])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)

    for await state in await centralManager.startStream() {
      if state == .poweredOn {
        break
      }
    }
  }

  func assertConnectionStateIsConnectionDisconnected(
    _ connectionState: PeripheralConnectionState, error: CBError
  ) {
    if case let .disconnected(err) = connectionState {
      #expect(err?.code == error.code)
    } else {
      Issue.record("Unexpected connection state \(connectionState)")
    }
  }

  @Test("Device disconnecting changes connection state with error")
  func testDeviceDisconnectingChangesConnectionStateWithError() async throws {

    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: {
        await $0.identifier == mockPeripheralSuccess.identifier
      })
    else {
      Issue.record("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let disconnectError = CBError(.peripheralDisconnected)
    mockPeripheralSuccess.simulateDisconnection(withError: disconnectError)

    for await connectionState in connectionStates {
      assertConnectionStateIsConnectionDisconnected(connectionState, error: disconnectError)

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionDisconnected(deviceConnectionState, error: disconnectError)
      break
    }
  }

  @Test("Cancel connection changes state to disconnecting and disconnected without error")
  func testCancelConnectionChangesStateToDisconnectingAndDisconnectedWithoutError() async throws {

    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: {
        await $0.identifier == mockPeripheralSuccess.identifier
      })
    else {
      Issue.record("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    try await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      #expect(deviceConnectionState == .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      #expect(deviceConnectionState == .disconnected(nil))
      break
    }
  }

  @Test("Cancel connection returns async stream")
  func testCancelConnectionReturnsAsyncStream() async throws {

    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: {
        await $0.identifier == mockPeripheralSuccess.identifier
      })
    else {
      Issue.record("couldn't get device")
      return
    }

    for await connectionState in try await centralManager.connect(device).dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = try await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      #expect(deviceConnectionState == .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      #expect(deviceConnectionState == .disconnected(nil))
      break
    }
  }

  @Test("Cancel connect throws when called while disconnected")
  func testCancelConnectThrowsWhenCalledWhileDisconnected() async throws {

    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: {
        await $0.identifier == mockPeripheralSuccess.identifier
      })
    else {
      Issue.record("couldn't get device")
      return
    }

    // Initially disconnected
    await #expect(
      throws: PeripheralConnectionError.self
    ) {
      try await centralManager.cancelPeripheralConnection(device)
    }

    for await connectionState in try await centralManager.connect(device).dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = try await centralManager.cancelPeripheralConnection(device)

    for await _ in connectionStates {
      await #expect(
        throws: PeripheralConnectionError.self
      ) {
        try await centralManager.cancelPeripheralConnection(device)
      }
      break
    }

    for await _ in connectionStates {

      await #expect(
        throws: PeripheralConnectionError.self
      ) {
        try await centralManager.cancelPeripheralConnection(device)
      }
      break
    }
  }

  @Test("Cancel connect throws when called after failure")
  func testCancelConnectThrowsWhenCalledAfterFailure() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: {
        await $0.identifier == mockPeripheralFailure.identifier
      })
    else {
      Issue.record("couldn't get device")
      return
    }

    for await _ in try await centralManager.connect(device).dropFirst() {
      break
    }

    await #expect(
      throws: PeripheralConnectionError.self
    ) {
      try await centralManager.cancelPeripheralConnection(device)
    }
  }
}
