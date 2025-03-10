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

    for await state in await centralManager.start() {
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

    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    let connectionStates = await centralManager.connect(device)

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
      let deviceConnectionState = await device.connectionState.current
      assertConnectionStateIsConnectionDisconnected(deviceConnectionState, error: disconnectError)
      break
    }
  }

  @Test("Cancel connection changes state to disconnecting and disconnected without error")
  func testCancelConnectionChangesStateToDisconnectingAndDisconnectedWithoutError() async throws {

    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    let connectionStates = await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState.current
      #expect(deviceConnectionState == .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState.current
      #expect(deviceConnectionState == .disconnected(nil))
      break
    }
  }

  @Test("Cancel connection returns async stream")
  func testCancelConnectionReturnsAsyncStream() async throws {

    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    for await connectionState in await centralManager.connect(device).dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState.current
      #expect(deviceConnectionState == .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      #expect(connectionState == .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState.current
      #expect(deviceConnectionState == .disconnected(nil))
      break
    }
  }

  @Test("Cancel connect returns state stream when called while disconnected")
  func testCancelConnectReturnsStateStreamWhenCalledWhileDisconnected() async throws {

    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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
    let initialDisconnectStream = await centralManager.cancelPeripheralConnection(device)
    for await connectionState in initialDisconnectStream {
      #expect(connectionState == .disconnected(nil))
      break
    }

    for await connectionState in await centralManager.connect(device).dropFirst() {
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = await centralManager.cancelPeripheralConnection(device)

    for await state in connectionStates {
      #expect(state == .disconnecting)
      
      // Call cancel again while disconnecting - should return stream without throwing
      let duplicateStream = await centralManager.cancelPeripheralConnection(device)
      for await duplicateState in duplicateStream {
        #expect(duplicateState == .disconnecting)
        break
      }
      break
    }

    for await state in connectionStates {
      #expect(state == .disconnected(nil))
      
      // Call cancel again while disconnected - should return stream without throwing
      let finalStream = await centralManager.cancelPeripheralConnection(device)
      for await finalState in finalStream {
        #expect(finalState == .disconnected(nil))
        break
      }
      break
    }
  }

  @Test("Cancel connect returns state stream when called after failure")
  func testCancelConnectReturnsStateStreamWhenCalledAfterFailure() async throws {
     let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    for await state in await centralManager.connect(device) {
      if state == .connected {
        break
      }
    }

    // Verify that we get the appropriate disconnected state
    for await connectionState in await centralManager.cancelPeripheralConnection(device).dropFirst() {
      // The error might be either connection failed or already disconnected
      if case .disconnected(let error) = connectionState {
        #expect(error == nil)
      } else {
        Issue.record("Expected .disconnected state, got \(connectionState)")
      }
      break
    }
  }
}
