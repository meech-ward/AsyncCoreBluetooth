import Testing

@testable import AsyncCoreBluetooth
@testable @preconcurrency import CoreBluetoothMock

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

  @Test("recieves the new value on the characteristic")
  func test_recievesNewValueOnCharacteristic() async throws {
    let peripheral = self.peripheral!
    let characteristic = self.characteristic!
    let cbPeripheral = await peripheral.cbPeripheral
    let cbCharacteristic = await characteristic.characteristic

    cbCharacteristic.value = "test".data(using: .utf8)
    await peripheral.peripheral(
      cbPeripheral, didUpdateValueFor: characteristic.characteristic, error: nil)

    #expect(await characteristic.value == "test".data(using: .utf8))
  }

  @Test("recieves the new value when notifying is enabled", .timeLimit(.minutes(1)))
  func test_recievesNewValueWhenNotifyingIsEnabled() async throws {
    let peripheral = self.peripheral!
    let characteristic = self.characteristic!
    let cbPeripheral = await peripheral.cbPeripheral
    let cbCharacteristic = await characteristic.characteristic

    cbCharacteristic.value = "test".data(using: .utf8)

    try await peripheral.setNotifyValue(true, for: characteristic)

    let stream = await characteristic.valueStream()

    var called = false
    Task {
      // drop the initial value
      for await result in stream {
        let value = try result.get()
        #expect(value == "test".data(using: .utf8))
        called = true
      }
    }

    try await Task.sleep(nanoseconds: 1_000_000)

    await peripheral.peripheral(
      cbPeripheral, didUpdateValueFor: characteristic.characteristic, error: nil)

    // give time for the stream to receive the new value
    try await Task.sleep(nanoseconds: 1_000_000)
    #expect(called == true)
  }

  @Test("recieves the new error when notifying is enabled", .timeLimit(.minutes(1)))
  func test_recievesNewErrorWhenNotifyingIsEnabled() async throws {
    let peripheral = self.peripheral!
    let characteristic = self.characteristic!
    let cbPeripheral = await peripheral.cbPeripheral
    let cbCharacteristic = await characteristic.characteristic

    cbCharacteristic.value = "test".data(using: .utf8)

    try await peripheral.setNotifyValue(true, for: characteristic)

    let stream = await characteristic.valueStream()

    var called = false
    Task {
      // drop the initial value
      for await result in stream {
        #expect(throws: CharacteristicError.unableToFindCharacteristics.self) {
          let _ = try result.get()
        }
        called = true
      }
    }

    try await Task.sleep(nanoseconds: 1_000_000)

    await peripheral.peripheral(
      cbPeripheral, didUpdateValueFor: characteristic.characteristic,
      error: CharacteristicError.unableToFindCharacteristics)

    // give time for the stream to receive the new value
    try await Task.sleep(nanoseconds: 1_000_000)
    #expect(called == true)
  }

  @Test("recieves no new value when notifying is disabled", .timeLimit(.minutes(1)))
  func test_recievesNoNewValueWhenNotifyingIsDisabled() async throws {
    let peripheral = self.peripheral!
    let characteristic = self.characteristic!
    let cbPeripheral = await peripheral.cbPeripheral
    let cbCharacteristic = await characteristic.characteristic

    cbCharacteristic.value = "test".data(using: .utf8)

    let stream = await characteristic.valueStream()

    var called = false
    Task {
      // drop the initial value
      for await _ in stream.dropFirst() {
        called = true
      }
    }

    try await Task.sleep(nanoseconds: 1_000_000)

    await peripheral.peripheral(
      cbPeripheral, didUpdateValueFor: characteristic.characteristic, error: nil)

    // give time for the stream to receive the new value
    try await Task.sleep(nanoseconds: 1_000_000)
    #expect(called == false)
  }

}
