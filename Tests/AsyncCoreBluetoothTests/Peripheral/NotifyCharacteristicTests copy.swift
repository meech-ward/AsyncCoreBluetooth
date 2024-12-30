@preconcurrency import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct NotifyCharacteristicTests {
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
    "Set notify true and false sets isNotifying true and false on the characteristic")
  func test_setNotifyTrueAndFalse_setsIsNotifyingTrueAndFalse() async throws {

    #expect(await characteristic.isNotifying == false)
    #expect(await characteristic.state.isNotifying == false)
    let isNotifying = try await peripheral.setNotifyValue(true, for: characteristic)
    #expect(isNotifying == true)
    #expect(await characteristic.isNotifying == true)
    #expect(await characteristic.state.isNotifying == true)

    let isNotifying2 = try await peripheral.setNotifyValue(false, for: characteristic)
    #expect(isNotifying2 == false)
    #expect(await characteristic.isNotifying == false)
    #expect(await characteristic.state.isNotifying == false)
  }
  


}
