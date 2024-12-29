import CoreBluetoothMock
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

  @Test func test_scan_returnsDevices() async throws {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    await peripheral.discoverServices([MockPeripheral.UUIDs.Device.service])
  }

}
