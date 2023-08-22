@testable import AsyncCoreBluetooth
import CoreBluetooth
import CoreBluetoothMock
import XCTest

final class DisconnectToNewDeviceTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  var mockPeripheralSuccess: CBMPeripheralSpec!
  var mockPeripheralFailure: CBMPeripheralSpec!
  var mockPeripheralSuccessDelegate: MockPeripheral.Delegate!
  var mockPeripheralFailureDelegate: MockPeripheral.Delegate!

  override func setUp() async throws {
    mockPeripheralSuccessDelegate = MockPeripheral.Delegate(peripheralDidReceiveConnectionRequestResult: .success(()))
    mockPeripheralFailureDelegate = MockPeripheral.Delegate(peripheralDidReceiveConnectionRequestResult: .failure(CBError(.connectionFailed)))
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

extension DisconnectToNewDeviceTests {
  func assertConnectionStateIsConnectionDisconnected(_ connectionState: Peripheral.ConnectionState, error: CBError) {
    if case let .disconnected(err) = connectionState {
      XCTAssertEqual(err!.code, error.code)
    } else {
      XCTFail("Unexpected connection state \(connectionState)")
    }
  }

  func test_deviceDisconnecting_changesConnectionStateWithError() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")
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

  func test_cancelConnection_changesConnectionStateToDisconnectingAndDisconnectedWithoutError() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    try await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      XCTAssertEqual(connectionState, .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      XCTAssertEqual(connectionState, .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnected(nil))
      break
    }
  }

  func test_cancelConnection_returnsAsyncStream() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    for await connectionState in try await centralManager.connect(device).dropFirst() {
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = try await centralManager.cancelPeripheralConnection(device)

    for await connectionState in connectionStates {
      XCTAssertEqual(connectionState, .disconnecting)

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnecting)
      break
    }

    for await connectionState in connectionStates {
      XCTAssertEqual(connectionState, .disconnected(nil))

      // Published connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .disconnected(nil))
      break
    }
  }

  func test_cancelConnect_throws_whenCalledWhileDisconnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    // Initially disconnected
    do {
      try await centralManager.cancelPeripheralConnection(device)
      XCTFail("Didn't throw error")
    } catch {
      XCTAssertNotNil(error)
    }

    for await connectionState in try await centralManager.connect(device).dropFirst() {
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")
      break
    }

    let connectionStates = try await centralManager.cancelPeripheralConnection(device)

    for await _ in connectionStates {
      do {
        try await centralManager.cancelPeripheralConnection(device)
        XCTFail("Didn't throw error")
      } catch {
        XCTAssertNotNil(error)
      }
      break
    }

    for await _ in connectionStates {
      do {
        try await centralManager.cancelPeripheralConnection(device)
        XCTFail("Didn't throw error")
      } catch {
        XCTAssertNotNil(error)
      }
      break
    }
  }

  func test_cancelConnect_throws_whenCalledAfterFailure() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralFailure.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    for await _ in try await centralManager.connect(device).dropFirst() {
      break
    }

    do {
      try await centralManager.cancelPeripheralConnection(device)
      XCTFail("Didn't throw error")
    } catch {
      XCTAssertNotNil(error)
    }
  }
}