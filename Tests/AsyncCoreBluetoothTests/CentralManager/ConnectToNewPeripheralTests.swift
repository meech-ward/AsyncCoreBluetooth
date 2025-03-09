import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct ConnectToNewPeripheralTests {
  var centralManager: CentralManager!

  var mockPeripheralSuccess: CBMPeripheralSpec!
  var mockPeripheralFailure: CBMPeripheralSpec!
  var mockPeripheralSuccessDelegate: MockPeripheral.Delegate!
  var mockPeripheralFailureDelegate: MockPeripheral.Delegate!

  init() async throws {
    mockPeripheralSuccessDelegate = MockPeripheral.Delegate(
      peripheralDidReceiveConnectionRequestResult: .success(())
    )
    mockPeripheralFailureDelegate = MockPeripheral.Delegate(
      peripheralDidReceiveConnectionRequestResult: .failure(CBMError(.connectionFailed))
    )
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

  // Initial disconnected and connecting states
  // MARK: - @Suite(.serialized) struct InitialStates {
  @Test("Connection state starts at disconnected")
  func testConnectionStateStartsAtDisconnected() async throws {
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

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      #expect(
        connectionState == .disconnected(nil),
        "Expected connectionState to be disconnected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .disconnected(nil),
        "Expected deviceConnectionState to be disconnected, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Connection state changes to connecting")
  func testConnectionStateChangesToConnecting() async throws {
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

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        await centralManager.connect(device)
        i += 1
        continue
      }
      // stream state
      #expect(
        connectionState == .connecting,
        "Expected connectionState to be connecting, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connecting,
        "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Connection state starts at disconnected and changes to connecting")
  func testConnectionStateStartsAtDisconnectedAndChangesToConnecting() async throws {
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

    // should start by being disconnected
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      #expect(
        connectionState == .disconnected(nil),
        "Expected connectionState to be disconnected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .disconnected(nil),
        "Expected deviceConnectionState to be disconnected, got \(deviceConnectionState)"
      )
      break
    }

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      #expect(
        connectionState == .connecting,
        "Expected connectionState to be connecting, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connecting,
        "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Connect with stream updates stream state to connecting")
  func testConnectWithStreamUpdatesStreamStateToConnecting() async throws {
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

    for await connectionState in connectionStates {
      // stream state
      #expect(
        connectionState == .connecting,
        "Expected connectionState to be connecting, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connecting,
        "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Initial connection states work for multiple listeners")
  func testInitialConnectionStatesWorkForMultipleListeners() async throws {
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

    @Sendable func assertConnectionStates(stream: AsyncStream<PeripheralConnectionState>) async {
      var i = 0
      for await connectionState in stream {
        let expectedState: PeripheralConnectionState = i == 0 ? .disconnected(nil) : .connecting
        i += 1

        #expect(
          connectionState == expectedState,
          "Expected connectionState to be \(expectedState), got \(connectionState)"
        )

        if i == 2 {
          break
        }
      }
    }

    let stream1 = await centralManager.connectionState(forPeripheral: device)
    let stream2 = await centralManager.connectionState(forPeripheral: device)
    let stream3 = await centralManager.connectionState(forPeripheral: device)
    let connectionStates = await centralManager.connect(device)

    await withTaskGroup(of: Void.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask {
        for await connectionState in connectionStates {
          #expect(
            connectionState == .connecting,
            "Expected connectionState to be connecting, got \(connectionState)"
          )
          break
        }
      }
    }
  }

  // Successful connected state
  // MARK: - @Suite(.serialized) struct SuccessfulConnection {

  @Test("Connection state changes to connecting and then connected")
  func testConnectionStateChangesToConnectingAndThenConnected() async throws {
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

    await centralManager.connect(device)

    // device connection state property
    var deviceConnectionState = await device.connectionState
    #expect(
      deviceConnectionState == .connecting,
      "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)"
    )

    // observable device connection state property
    var deviceConnectionStateObservable = await device.state.connectionState
    #expect(
      deviceConnectionStateObservable == .connecting,
      "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)"
    )

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if connectionState == .connected {
        break
      }
    }

    // device connection state property
    deviceConnectionState = await device.connectionState
    #expect(
      deviceConnectionState == .connected,
      "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
    )

    // observable device connection state property
    deviceConnectionStateObservable = await device.state.connectionState
    #expect(
      deviceConnectionStateObservable == .connected,
      "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
    )

  }

  @Test("Connection state changes to connected in stream")
  func testConnectionStateChangesToConnectedInStream() async throws {
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

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        await centralManager.connect(device)
        i += 1
        continue
      }
      if i == 1 {
        i += 1
        continue
      }
      // stream state
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connected,
        "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
      )

      // observable device connection state property
      let deviceConnectionStateObservable = await device.state.connectionState
      #expect(
        deviceConnectionStateObservable == .connected,
        "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Connection state is connected")
  func testConnectionStateIsConnected() async throws {
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device)
      .dropFirst()
    {
      // stream state
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connected,
        "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Connect with stream is connected")
  func testConnectWithStreamIsConnected() async throws {
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
      // stream state
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connected,
        "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Initial connected state works for multiple listeners")
  func testInitialConnectedStateWorksForMultipleListeners() async throws {
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

    @Sendable func assertConnectionStates(
      stream: AsyncDropFirstSequence<AsyncStream<PeripheralConnectionState>>
    ) async {
      for await connectionState in stream {
        let expectedState: PeripheralConnectionState = .connected
        #expect(
          connectionState == expectedState,
          "Expected connectionState to be \(expectedState), got \(connectionState)"
        )
        break
      }
    }

    let stream1 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream2 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream3 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let connectionStates = await centralManager.connect(device).dropFirst()

    await withTaskGroup(of: Void.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask { await assertConnectionStates(stream: connectionStates) }
    }
  }

  // Unsuccessful connected state
  // MARK: - @Suite(.serialized) struct UnsuccessfulConnection {
  func assertConnectionStateIsConnectionFailed(_ connectionState: PeripheralConnectionState) {
    if case let .failedToConnect(err) = connectionState {
      #expect(err.code == CBMError.connectionFailed)
    }
    else {
      Issue.record(
        "Unexpected connection state expected \(connectionState) to be connectionFailed"
      )
    }
  }

  @Test("Connection state changes to failed")
  func testConnectionStateChangesToFailed() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        await centralManager.connect(device)
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

  @Test("Connection state is failed")
  func testConnectionStateIsFailed() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device)
      .dropFirst()
    {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }
  }

  @Test("Connect with stream is failed")
  func testConnectWithStreamIsFailed() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    let connectionStates = await centralManager.connect(device)

    for await connectionState in connectionStates.dropFirst() {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }
  }

  @Test("Can successfully connect after failure")
  func testCanSuccessfullyConnectAfter() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device)
      .dropFirst()
    {
      // stream state
      assertConnectionStateIsConnectionFailed(connectionState)

      // device connection state property
      let deviceConnectionState = await device.connectionState
      assertConnectionStateIsConnectionFailed(deviceConnectionState)
      break
    }

    mockPeripheralFailureDelegate.peripheralDidReceiveConnectionRequestResult = .success(())

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device)
      .dropFirst()
    {
      // stream state
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)"
      )

      // device connection state property
      let deviceConnectionState = await device.connectionState
      #expect(
        deviceConnectionState == .connected,
        "Expected deviceConnectionState to be connected, got \(deviceConnectionState)"
      )
      break
    }
  }

  @Test("Initial failed state works for multiple listeners")
  func testInitialFailedStateWorksForMultipleListeners() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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

    func assertConnectionStates(
      stream: AsyncDropFirstSequence<AsyncStream<PeripheralConnectionState>>
    ) async -> PeripheralConnectionState? {
      for await connectionState in stream {
        return connectionState
      }
      return nil
    }

    let stream1 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream2 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let stream3 = await centralManager.connectionState(forPeripheral: device).dropFirst(2)
    let connectionStates = await centralManager.connect(device).dropFirst()

    await withTaskGroup(of: PeripheralConnectionState?.self) { taskGroup in
      taskGroup.addTask { await assertConnectionStates(stream: stream1) }
      taskGroup.addTask { await assertConnectionStates(stream: stream2) }
      taskGroup.addTask { await assertConnectionStates(stream: stream3) }
      taskGroup.addTask { await assertConnectionStates(stream: connectionStates) }

      for await state in taskGroup {
        guard let state = state else {
          Issue.record("Expected connection state to be connectionFailed, got nil")
          continue
        }
        assertConnectionStateIsConnectionFailed(state)
      }
    }
  }

  // Already connecting or connected
  // MARK: - @Suite(.serialized) struct AlreadyConnectingOrConnected {
  @Test("Connect returns current state stream when called while connecting")
  func testConnectReturnsCurrentStateStreamWhenCalledWhileConnecting() async throws {
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      #expect(
        connectionState == .connecting,
        "Expected connectionState to be connecting, got \(connectionState)"
      )

      // Should return the stream with the current state when already connecting
      let duplicateStream = await centralManager.connect(device)
      for await duplicateState in duplicateStream {
        #expect(duplicateState == .connecting)
        break
      }

      break
    }
  }

  @Test("Connect returns current state stream when called while connected")
  func testConnectReturnsCurrentStateStreamWhenCalledWhileConnected() async throws {
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device).dropFirst() {
      // stream state
      #expect(
        connectionState == .connected,
        "Expected connectionState to be connected, got \(connectionState)"
      )

      // Should return the stream with the current state when already connected
      let duplicateStream = await centralManager.connect(device)
      for await duplicateState in duplicateStream {
        #expect(duplicateState == .connected)
        break
      }

      break
    }
  }
}
