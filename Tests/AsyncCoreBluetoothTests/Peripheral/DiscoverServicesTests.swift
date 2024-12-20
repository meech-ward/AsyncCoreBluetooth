@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class DiscoverServicesTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  lazy var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.Delegate(), isKnown: true)

  var peripheral: Peripheral!

  override func setUp() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    _ = await centralManager.start().first(where: {$0 == .poweredOn})

    peripheral = await centralManager.retrievePeripherals(withIdentifiers: [mockPeripheral.identifier])[0]

  }

  override func tearDown() async throws {
    _ = try? await centralManager.cancelPeripheralConnection(peripheral)
    centralManager = nil
  }

  func test_scan_returnsDevices() async throws {
    _ = try await centralManager.connect(peripheral).first(where: { $0 == .connected })

    // await peripheral.discoverServices([.battery, .deviceInformation])
  }

}
