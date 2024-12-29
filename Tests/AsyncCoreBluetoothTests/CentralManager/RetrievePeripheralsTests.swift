import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct RetrievePeripheralsTests {
  var centralManager: CentralManager!

  var mockPeripheral1: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)
  var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)
  var mockPeripheral3: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: false)

  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral1, mockPeripheral2, mockPeripheral3])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.startStream() {
      if state == .poweredOn {
        break
      }
    }
  }

  @Test("Returns the peripherals when retrieving with identifiers")
  func testReturnsThePeripherals() async throws {
    let devices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    #expect(devices.count == 2)
  }

  @Test("Returns the same peripherals each time when retrieving with identifiers")
  func testReturnsSamePeripheralsEachTime() async throws {
    let devicesOne = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    let devicesTwo = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    #expect(devicesOne[0] === devicesTwo[0])
    #expect(devicesOne[1] === devicesTwo[1])
  }

  @Test("Returns the same peripherals from scanning and connecting")
  func testReturnsSamePeripheralsFromScanningAndConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier })
    else {
      Issue.record("couldn't get device")
      return
    }

    _ = try await centralManager.connect(device).first(where: { $0 == .connected })

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral3.identifier
    ])

    #expect(retrievedDevices.count == 1)
    #expect(retrievedDevices[0] === device)
  }

  @Test("Responds to same events as scanning and connecting - disconnect test")
  func testRespondsToSameEventsAsScanningAndConnecting1() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier })
    else {
      Issue.record("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)
    for await state in connectionStates {
      if state == .connected {
        break
      }
    }

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral3.identifier
    ])

    try await centralManager.cancelPeripheralConnection(retrievedDevices[0])
    let state = await connectionStates.first(where: { _ in true })
    #expect(state == .disconnecting)
  }

  @Test("Responds to same events as scanning and connecting - error test")
  func testRespondsToSameEventsAsScanningAndConnecting2() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier })
    else {
      Issue.record("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)
    for await state in connectionStates {
      if state == .connected {
        break
      }
    }

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral3.identifier
    ])

    async let state1 = connectionStates.first(where: { _ in true })
    let state2a = await centralManager.connectionState(forPeripheral: retrievedDevices[0])
      .dropFirst()
    async let state2 = await state2a.first(where: { _ in true })
    mockPeripheral3.simulateDisconnection(withError: CBMError(.peripheralDisconnected))
    for state in await [state1, state2] {
      #expect(state == .disconnected(CBMError(.peripheralDisconnected)))
    }
  }
}
