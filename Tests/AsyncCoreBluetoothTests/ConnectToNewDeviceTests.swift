@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class ConnectToNewDeviceTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  lazy var mockPeripheralSuccess: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.SuccessConnectionDelegate())
  lazy var mockPeripheralFailure: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.FailureConnectionDelegate())

  override func setUp() async throws {
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

  func test_connectionState_changesToConnected() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    var i = 0
    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      if i == 0 {
        await centralManager.connect(device)
        i += 1
        break
      }
      // stream state
      XCTAssertEqual(connectionState, .connected, "Expected connectionState to be connected, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connected, "Expected deviceConnectionState to be connected, got \(deviceConnectionState)")
      break
    }
  }

  func test_connectionState_startsAtDisconnected_andChangesToDisconnected() async throws {
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

    await centralManager.connect(device)

    for await connectionState in await centralManager.connectionState(forPeripheral: device) {
      // stream state
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connecting, "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)")
      break
    }
  }

  func test_connectWithStream_updatesStreamState_andDeviceState() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheralSuccess.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = await centralManager.connect(device)

    // very first time will be connecting
    for await connectionState in connectionStates {
      // stream state
      XCTAssertEqual(connectionState, .connecting, "Expected connectionState to be connecting, got \(connectionState)")

      // device connection state property
      let deviceConnectionState = await device.connectionState
      XCTAssertEqual(deviceConnectionState, .connecting, "Expected deviceConnectionState to be connecting, got \(deviceConnectionState)")
      break
    }
    // // then will connect
    // for await connectionState in connectionStates {
    //   XCTAssertEqual(connectionState, .connected)

    //   // Published connection state property
    //   let deviceConnectionState = await device.connectionState
    //   XCTAssertEqual(deviceConnectionState, .connected)
    //   break
    // }
  }
}

  // func test_connect_success_updatesDeviceState() async throws {
  //   let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
  //   guard let device = await devices.first(where: { $0.identifier == mockPeripheralSuccess.identifier }) else {
  //     XCTFail("couldn't get device")
  //     return
  //   }

  //   let connectionStates = try await device.connect()
  //   // very first time will be connecting

  //   for await connectionState in connectionStates {
  //     XCTAssertEqual(connectionState, .connecting)

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     XCTAssertEqual(deviceConnectionState, .connecting)
  //     break
  //   }
  //   // then will connect
  //   for await connectionState in connectionStates {
  //     XCTAssertEqual(connectionState, .connected)

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     XCTAssertEqual(deviceConnectionState, .connected)
  //     break
  //   }
  // }

  // func test_connect_failure_updatesDeviceState() async throws {
  //   let devices = try await centralManager.scanForPeripherals(withServices: [UUIDs.Device.service])
  //   guard let device = await devices.first(where: { $0.identifier == mockPeripheral2.identifier }) else {
  //     XCTFail("couldn't get device")
  //     return
  //   }

  //   let connectionStates = try await device.connect()
  //   // very first time will be not connected
  //   for await connectionState in connectionStates {
  //     XCTAssertEqual(connectionState, .connecting)

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     XCTAssertEqual(deviceConnectionState, .connecting)
  //     break
  //   }

  //   // then will fail to connect
  //   for await connectionState in connectionStates {
  //     if case let .failedToConnect(err) = connectionState {
  //       XCTAssertEqual(err.code, CBMError.connectionFailed)
  //     } else {
  //       XCTFail("Unexpected connection state expected \(connectionState) to be connectionFailed")
  //     }

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     if case let .failedToConnect(err) = deviceConnectionState {
  //       XCTAssertEqual(err.code, CBMError.connectionFailed)
  //     } else {
  //       XCTFail("Unexpected connection state expected \(deviceConnectionState) to be connectionFailed")
  //     }
  //     break
  //   }
  // }

  // func test_deviceDisconnected_updatesDeviceState() async throws {
  //   let devices = try await centralManager.scanForPeripherals(withServices: [UUIDs.Device.service])
  //   guard let device = await devices.first(where: { $0.identifier == mockPeripheral.identifier }) else {
  //     XCTFail("couldn't get device")
  //     return
  //   }

  //   let connectionStates = try await device.connect()
  //   // wait for connection
  //   for await connectionState in connectionStates.dropFirst(1) {
  //     XCTAssertEqual(connectionState, .connected)
  //     break
  //   }

  //   mockPeripheral.simulateDisconnection(withError: CBMError(.peripheralDisconnected))

  //   for await connectionState in connectionStates {
  //     if case let .disconnected(err) = connectionState {
  //       XCTAssertEqual(err!.code, CBMError.peripheralDisconnected)
  //     } else {
  //       XCTFail("Unexpected connection state \(connectionState.text())")
  //     }

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     if case let .disconnected(err) = deviceConnectionState {
  //       XCTAssertEqual(err!.code, CBMError.peripheralDisconnected)
  //     } else {
  //       XCTFail("Unexpected connection state")
  //     }
  //     break
  //   }
  // }

  // func test_centralDisconnect_updatesDeviceState() async throws {
  //   let devices = try await centralManager.scanForPeripherals(withServices: [UUIDs.Device.service])
  //   guard let device = await devices.first(where: { $0.identifier == mockPeripheral.identifier }) else {
  //     XCTFail("couldn't get device")
  //     return
  //   }

  //   let connectionStates = try await device.connect()
  //   // wait for connection
  //   for await connectionState in connectionStates.dropFirst(1) {
  //     XCTAssertEqual(connectionState, .connected)
  //     break
  //   }

  //   await device.disconnect()

  //   for await connectionState in connectionStates {
  //     if case let .disconnected(err) = connectionState {
  //       XCTAssertNil(err)
  //     } else {
  //       XCTFail("Unexpected connection state \(connectionState.text())")
  //     }

  //     // Published connection state property
  //     let deviceConnectionState = await device.connectionState
  //     if case let .disconnected(err) = deviceConnectionState {
  //       XCTAssertNil(err)
  //     } else {
  //       XCTFail("Unexpected connection state")
  //     }
  //     break
  //   }
  // }

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

