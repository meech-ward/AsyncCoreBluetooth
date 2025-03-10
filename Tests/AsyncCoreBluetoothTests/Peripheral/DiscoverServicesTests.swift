@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct DiscoverServicesTests {
  var centralManager: CentralManager!

  lazy var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)

  var peripheral: Peripheral!

  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    _ = await centralManager.start().first(where: { $0 == .poweredOn })

    peripheral = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral.identifier
    ])[0]

  }

  @Test("Discover services returns services") func test_discoverServices_returnsServices()
    async throws
  {
    _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = try await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services[MockPeripheral.UUIDs.Device.service] else {
      Issue.record("couldn't get device")
      return
    }
    #expect(await service.uuid == MockPeripheral.UUIDs.Device.service)
  }

  @Test("Discover services sets the services") func test_discoverServices_setsTheServices()
    async throws
  {
    _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = try await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services[MockPeripheral.UUIDs.Device.service],
      let peripheralService = await peripheral.services.current?.first
    else {
      Issue.record("couldn't get all servies")
      return
    }
    #expect(service === peripheralService)
  }

  @Test("Discover services references the peripheral")
  func test_discoverServices_referencesThePeripheral()
    async throws
  {
    _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = try await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services[MockPeripheral.UUIDs.Device.service] else {
      Issue.record("couldn't get device")
      return
    }
    #expect(await service.peripheral === peripheral)
  }

  @Test("Discover services called multiple times back to back returns the same service")
  func test_discoverServices_calledMultipleTimesBackToBackReturnsTheSameService() async throws {
    _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })
    let peripheral = self.peripheral!

    async let servicesAsync = [
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
    ]
    let services = try await servicesAsync
    guard let service1 = services[0][MockPeripheral.UUIDs.Device.service], let service2 = services[1][MockPeripheral.UUIDs.Device.service],
      let service3 = services[2][MockPeripheral.UUIDs.Device.service], let service4 = services[3][MockPeripheral.UUIDs.Device.service],
      let service5 = services[4][MockPeripheral.UUIDs.Device.service], let service6 = services[5][MockPeripheral.UUIDs.Device.service]
    else {
      Issue.record("couldn't get services")
      return
    }
    #expect(await service1.uuid == service2.uuid)
    #expect(await service1.uuid == service3.uuid)
    #expect(await service1.uuid == service4.uuid)
    #expect(await service1.uuid == service5.uuid)
    #expect(await service1.uuid == service6.uuid)
  }
}
