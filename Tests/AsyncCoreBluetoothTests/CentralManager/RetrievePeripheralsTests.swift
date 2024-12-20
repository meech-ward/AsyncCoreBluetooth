@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class RetrievePeripheralsTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  lazy var mockPeripheral1: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate(), isKnown: true)
  lazy var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate(), isKnown: true)
  lazy var mockPeripheral3: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate(), isKnown: false)

  override func setUp() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral1, mockPeripheral2, mockPeripheral3])
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

  func test_retrievePeripheralsWithIdentifiers_returnsThePeripherals() async throws {
    let devices = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral1.identifier, mockPeripheral2.identifier])
    XCTAssertEqual(devices.count, 2)
  }

  func test_retrievePeripheralsWithIdentifiers_returnsTheSamePeripheralsEachTime() async throws {
    let devicesOne = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral1.identifier, mockPeripheral2.identifier])
    let devicesTwo = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral1.identifier, mockPeripheral2.identifier])
    XCTAssertIdentical(devicesOne[0], devicesTwo[0])
    XCTAssertIdentical(devicesOne[1], devicesTwo[1])
  }

  func test_retrievePeripheralsWithIdentifiers_returnsTheSamePeripheralsFromScanningAndConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    _ = try await centralManager.connect(device).first(where: { $0 == .connected })

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral3.identifier])

    XCTAssertEqual(retrievedDevices.count, 1)
    XCTAssertIdentical(retrievedDevices[0], device)
  }

  func test_retrievePeripheralsWithIdentifiers_respondsToSameEventsAsScanningAndConnecting1() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)
    for await state in connectionStates {
      if state == .connected {
        break
      }
    }

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral3.identifier])

    try await centralManager.cancelPeripheralConnection(retrievedDevices[0])
    let state = await connectionStates.first(where: { _ in true })
    XCTAssertEqual(state, .disconnecting)
  }

  func test_retrievePeripheralsWithIdentifiers_respondsToSameEventsAsScanningAndConnecting2() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    guard let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier }) else {
      XCTFail("couldn't get device")
      return
    }

    let connectionStates = try await centralManager.connect(device)
    for await state in connectionStates {
      if state == .connected {
        break
      }
    }

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral3.identifier])

    async let state1 = connectionStates.first(where: { _ in true })
    async let state2 = await centralManager.connectionState(forPeripheral: retrievedDevices[0]).dropFirst().first(where: { _ in true })
    mockPeripheral3.simulateDisconnection(withError: CBMError(.peripheralDisconnected))
    for state in await [state1, state2] {
      XCTAssertEqual(state, .disconnected(CBMError(.peripheralDisconnected)))
    }
  }
}
