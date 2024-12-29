@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct ReadCharacteristicTests {
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

    let services = await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services.first else {
      Issue.record("couldn't get device")
      return
    }
    self.service = service

    let characteristics = await peripheral.discoverCharacteristics(
      [MockPeripheral.UUIDs.Device.characteristic], for: service)
    guard let characteristic = characteristics.first else {
      Issue.record("couldn't get characteristic")
      return
    }
    self.characteristic = characteristic
  }

  @Test("Read characteristic returns data", arguments: ["test", "test2", "test3", "test4"])
  func test_readCharacteristic_returnsData(_ testData: String) async throws {

    mockPeripheralDelegate.readData = testData.data(using: .utf8)

    let data = try await peripheral.readValue(for: characteristic)
    guard let data else {
      Issue.record("couldn't get data")
      return
    }
    let receivedString = String(data: data, encoding: .utf8)
    #expect(receivedString == testData)
  }

  @Test(
    "Read characteristic sets data on characteristic",
    arguments: ["test", "test2", "test3", "test4"])
  func test_readCharacteristic_setsDataOnCharacteristic(_ testData: String) async throws {

    mockPeripheralDelegate.readData = testData.data(using: .utf8)

    try await peripheral.readValue(for: characteristic)
    guard let characteristicValue = await characteristic.value else {
      Issue.record("couldn't get data")
      return
    }
    var receivedString = String(data: characteristicValue, encoding: .utf8)
    #expect(receivedString == testData)

    guard let characteristicStateValue = await characteristic.state.value else {
      Issue.record("couldn't get data")
      return
    }
    receivedString = String(data: characteristicStateValue, encoding: .utf8)
    #expect(receivedString == testData)
  }

}
