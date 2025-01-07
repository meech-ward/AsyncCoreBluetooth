import CoreBluetoothMock
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct RetrievePeripheralsTests {
  var centralManager: CentralManager!

  var mockPeripheral1: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)
  var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: true)
  var mockPeripheral3: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate(), isKnown: false)

  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral1, mockPeripheral2, mockPeripheral3])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.startStream() {
      if state == .poweredOn {
        break
      }
    }
  }

  @Test("Returns the peripherals when retrieving with identifiers")
  func testReturnsThePeripherals() async throws {
    let devices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    #expect(devices.count == 2)
  }

  @Test("Doesn't return the same peripherals each time when retrieving with identifiers")
  func testReturnsSamePeripheralsEachTime() async throws {
    // it needs to returna new async core bluetooth peripheral each time and do a complete setup of the delegate
    let devicesOne = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    let devicesTwo = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral1.identifier, mockPeripheral2.identifier,
    ])
    #expect(devicesOne[0] !== devicesTwo[0])
    #expect(devicesOne[1] !== devicesTwo[1])
  }

  @Test("Returns a different peripheral from scanning and connecting")
  func testReturnsSamePeripheralsFromScanningAndConnecting() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    guard
      let device = await devices.first(where: { await $0.identifier == mockPeripheral3.identifier })
    else {
      Issue.record("couldn't get device")
      return
    }

    _ = try await centralManager.connect(device).first(where: { $0 == .connected })

    let retrievedDevices = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral3.identifier
    ])

    #expect(retrievedDevices.count == 1)
    #expect(retrievedDevices[0] !== device)
  }
}
