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

  @Test(
    "Read characteristic returns data",
    arguments: [
      "test", "test2", "test3", "test4", "test5", "test6", "test7", "test8", "test9", "test10",
      "test11", "test12", "test13", "test14", "test15", "test16", "test17", "test18", "test19",
      "test20",
    ])
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
    "Read characteristic returns all data when called async")
  func test_readCharacteristic_returnsData_async() async throws {
    let peripheral = self.peripheral!
    let characteristic = self.characteristic!

    mockPeripheralDelegate.readData = "test".data(using: .utf8)
    async let data = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test2".data(using: .utf8)
    async let data2 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test3".data(using: .utf8)
    async let data3 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test4".data(using: .utf8)
    async let data4 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test5".data(using: .utf8)
    async let data5 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test6".data(using: .utf8)
    async let data6 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test7".data(using: .utf8)
    async let data7 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test8".data(using: .utf8)
    async let data8 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test9".data(using: .utf8)
    async let data9 = try await peripheral.readValue(for: characteristic)
    mockPeripheralDelegate.readData = "test10".data(using: .utf8)
    async let data10 = try await peripheral.readValue(for: characteristic)

    guard let data = try await data, let data2 = try await data2, let data3 = try await data3, let data4 = try await data4, let data5 = try await data5, let data6 = try await data6, let data7 = try await data7, let data8 = try await data8, let data9 = try await data9, let data10 = try await data10 else {
      Issue.record("couldn't get data")
      return
    }
    print(String(data: data, encoding: .utf8) ?? "nil")
    print(String(data: data2, encoding: .utf8) ?? "nil")
    print(String(data: data3, encoding: .utf8) ?? "nil")
    print(String(data: data4, encoding: .utf8) ?? "nil")
    print(String(data: data5, encoding: .utf8) ?? "nil")
    print(String(data: data6, encoding: .utf8) ?? "nil")
    print(String(data: data7, encoding: .utf8) ?? "nil")
    print(String(data: data8, encoding: .utf8) ?? "nil")
    print(String(data: data9, encoding: .utf8) ?? "nil")
    print(String(data: data10, encoding: .utf8) ?? "nil")
    // let receivedString = String(data: data, encoding: .utf8)
    // #expect(receivedString == testData)
  }

  @Test(
    "Read characteristic sets data on characteristic",
    arguments: [
      "test", "test2", "test3", "test4", "test5", "test6", "test7", "test8", "test9", "test10",
      "test11", "test12", "test13", "test14", "test15", "test16", "test17", "test18", "test19",
      "test20",
    ])
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
