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
    _ = await centralManager.startStream().first(where: { $0 == .poweredOn })

    peripheral = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral.identifier
    ])[0]

  }

  @Test("Discover services returns services") func test_discoverServices_returnsServices()
    async throws
  {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services.first else {
      Issue.record("couldn't get device")
      return
    }
    #expect(await service.uuid == MockPeripheral.UUIDs.Device.service)
  }

  @Test("Discover services sets the services") func test_discoverServices_setsTheServices()
    async throws
  {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services.first,
      let peripheralService = await peripheral.services?.first,
      let peripheralStateService = await peripheral.state.services?.first
    else {
      Issue.record("couldn't get all servies")
      return
    }
    #expect(await service === peripheralService)
    #expect(await service === peripheralStateService)
  }

  @Test("Discover services references the peripheral")
  func test_discoverServices_referencesThePeripheral()
    async throws
  {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    let services = await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
    guard let service = services.first else {
      Issue.record("couldn't get device")
      return
    }
    #expect(await service.peripheral === peripheral)
  }

  @Test("Discover services called multiple times back to back returns the same service")
  func test_discoverServices_calledMultipleTimesBackToBackReturnsTheSameService() async throws {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })
    let peripheral = self.peripheral!

    async let servicesAsync = [
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
      peripheral.discoverServices([MockPeripheral.UUIDs.Device.service]),
    ]
    let services = await servicesAsync
    guard let service1 = services[0].first, let service2 = services[1].first,
      let service3 = services[2].first, let service4 = services[3].first,
      let service5 = services[4].first, let service6 = services[5].first
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
