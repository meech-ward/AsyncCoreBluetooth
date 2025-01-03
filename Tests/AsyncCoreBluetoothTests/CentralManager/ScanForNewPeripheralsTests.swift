@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import Testing

@Suite(.serialized) struct ScanForNewPeripheralsTests {
  var centralManager: CentralManager!

  var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate())
  var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate())

  init() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral, mockPeripheral2])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.startStream() {
      if state == .poweredOn {
        break
      }
    }
  }

  @Test("Scan returns devices")
  func testScanReturnsDevices() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])
    for await device in devices {
      let id = await device.identifier
      #expect(id == mockPeripheral.identifier)
      break
    }
    for await device in devices {
      let id = await device.identifier
      #expect(id == mockPeripheral2.identifier)
      break
    }
  }

  @Test("Scan throws when called multiple times")
  func testScanThrowsWhenCalledMultipleTimes() async throws {
    let service = MockPeripheral.UUIDs.Device.service
    let centralManager = self.centralManager!
    
    await #expect(throws: CentralManagerError.alreadyScanning.self) {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          _ = try await centralManager.scanForPeripherals(withServices: [service])
        }
        group.addTask {
          _ = try await centralManager.scanForPeripherals(withServices: [service])
        }
        try await group.next()
        try await group.next()  
      }
    }
  }

  @Test("Scan throws when device not powered on")
  func testScanThrowsWhenDeviceNotPoweredOn() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    await #expect(throws: Error.self) {
      _ = try await centralManager.scanForPeripherals(withServices: [
        MockPeripheral.UUIDs.Device.service
      ])
    }
  }

  @Test("Scan ends when task is canceled")
  func testScanEndsWhenTaskIsCanceled() async throws {
    func assertAllScanning(_ expectedState: Bool = false) async throws {
      try await Task.sleep(nanoseconds: 1)
      try await Task.sleep(nanoseconds: 1)
      
      // Internal State
      let internalIsScanning = await centralManager.isScanning
      #expect(
        internalIsScanning == expectedState,
        "internalIsScanning should be \(expectedState)"
      )

      // Core Bluetooth state
      let isScanningCoreBLE = await centralManager.centralManager.isScanning
      #expect(
        isScanningCoreBLE == expectedState,
        "isScanningCoreBLE should be \(expectedState)"
      )

      try await Task.sleep(nanoseconds: 1)
      // Public published state
      let isScanning = await centralManager.isScanning
      #expect(
        isScanning == expectedState,
        "isScanning should be \(expectedState)"
      )
    }

    // false before scanning
    try await assertAllScanning(false)

    // true while scanning
    for await device in try await centralManager.scanForPeripherals(withServices: [
      MockPeripheral.UUIDs.Device.service
    ]) {
      let id = await device.identifier
      #expect(id == mockPeripheral.identifier)
      try await assertAllScanning(true)
      break
    }

    // false after scanning is complete
    try await assertAllScanning(false)
  }
}
