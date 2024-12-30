@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct WriteCharacteristicTests {
  var centralManager: CentralManager!

  let mockPeripheralDelegate = MockPeripheral.Delegate()
  lazy var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: mockPeripheralDelegate, isKnown: true)

  var peripheral: Peripheral!
  var service: Service!
  var characteristic: Characteristic!
  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    _ = await centralManager.startStream().first(where: { $0 == .poweredOn })

    peripheral = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral.identifier
    ])[0]
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = try await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services[MockPeripheral.UUIDs.Device.service] else {
      Issue.record("couldn't get device")
      return
    }
    self.service = service

    let characteristics = try await peripheral.discoverCharacteristics(
      [MockPeripheral.UUIDs.Device.characteristic], for: service)
    guard let characteristic = characteristics[MockPeripheral.UUIDs.Device.characteristic] else {
      Issue.record("couldn't get characteristic")
      return
    }
    self.characteristic = characteristic
  }

  // MARK: - Write Without Response

  @Test("Write characteristic writes data", arguments: ["test", "test2", "test3", "test4"])
  func test_writeCharacteristic(_ testData: String) async throws {

    mockPeripheralDelegate.readData = testData.data(using: .utf8)

    await peripheral.writeValueWithoutResponse(
      testData.data(using: .utf8)!, for: characteristic)
  }

  // MARK: - Write With Response

  @Test("Write characteristic returns data", arguments: ["test", "test2", "test3", "test4", "test5", "test6", "test7", "test8", "test9", "test10", "test11", "test12", "test13", "test14", "test15", "test16", "test17", "test18", "test19", "test20"])
  func test_writeCharacteristic_returnsData(_ testData: String) async throws {

    mockPeripheralDelegate.readData = testData.data(using: .utf8)

    try await peripheral.writeValueWithResponse(testData.data(using: .utf8)!, for: characteristic)
  }

}
