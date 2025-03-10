@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct DiscoverCharacteristicsTests {
  var centralManager: CentralManager!

  lazy var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)

  var peripheral: Peripheral!

  var service: Service!

  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    _ = await centralManager.start().first(where: { $0 == .poweredOn })

    peripheral = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral.identifier
    ])[0]
    _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = try await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services[MockPeripheral.UUIDs.Device.service] else {
      Issue.record("couldn't get device")
      return
    }
    self.service = service
  }

  @Test("Discover characteristics returns characteristics")
  func test_discoverServices_returnsServices()
    async throws
  {
    let characteristics = try await peripheral.discoverCharacteristics(
      [MockPeripheral.UUIDs.Device.characteristic], for: service)
    guard let characteristic = characteristics[MockPeripheral.UUIDs.Device.characteristic] else {
      Issue.record("couldn't get characteristic")
      return
    }

    #expect(await characteristic.uuid == MockPeripheral.UUIDs.Device.characteristic)
  }

  @Test("Discover characteristics sets the characteristics")
  func test_discoverServices_setsTheCharacteristics()
    async throws
  {
    let characteristics = try await peripheral.discoverCharacteristics(
      [MockPeripheral.UUIDs.Device.characteristic], for: service)
    guard let characteristic = characteristics[MockPeripheral.UUIDs.Device.characteristic],
      let serviceCharacteristic = await service.characteristics.current?.first
    else {
      Issue.record("couldn't get all characteristics")
      return
    }
    #expect(characteristic === serviceCharacteristic)
  }

  @Test("Discover characteristics references the service")
  func test_discoverServices_referencesTheService()
    async throws
  {
    let characteristics = try await peripheral.discoverCharacteristics(
      [MockPeripheral.UUIDs.Device.characteristic], for: service)
    guard let characteristic = characteristics[MockPeripheral.UUIDs.Device.characteristic] else {
      Issue.record("couldn't get characteristic")
      return
    }
    #expect(await characteristic.service === service)
  }

  @Test(
    "Discover characteristics called multiple times back to back returns the same characteristic")
  func test_discoverCharacteristics_calledMultipleTimesBackToBackReturnsTheSameCharacteristic()
    async throws
  {
    let peripheral = self.peripheral!

    async let characteristicsAsync = [
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
      peripheral.discoverCharacteristics(
        [MockPeripheral.UUIDs.Device.characteristic], for: service),
    ]
    let characteristics = try await characteristicsAsync
    guard let characteristic1 = characteristics[0][MockPeripheral.UUIDs.Device.characteristic],
      let characteristic2 = characteristics[1][MockPeripheral.UUIDs.Device.characteristic],
      let characteristic3 = characteristics[2][MockPeripheral.UUIDs.Device.characteristic],
      let characteristic4 = characteristics[3][MockPeripheral.UUIDs.Device.characteristic],
      let characteristic5 = characteristics[4][MockPeripheral.UUIDs.Device.characteristic],
      let characteristic6 = characteristics[5][MockPeripheral.UUIDs.Device.characteristic]
    else {
      Issue.record("couldn't get characteristics")
      return
    }
    #expect(await characteristic1.uuid == characteristic2.uuid)
    #expect(await characteristic1.uuid == characteristic3.uuid)
    #expect(await characteristic1.uuid == characteristic4.uuid)
    #expect(await characteristic1.uuid == characteristic5.uuid)
    #expect(await characteristic1.uuid == characteristic6.uuid)
  }
}
