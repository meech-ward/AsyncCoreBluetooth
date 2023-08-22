@testable import AsyncCoreBluetooth
import CoreBluetoothMock
import XCTest

final class ScanForNewDevicesTests: XCTestCase, XCTestObservation {
  var centralManager: CentralManager!

  lazy var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.SuccessConnectionDelegate())
  lazy var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(delegate: MockPeripheral.SuccessConnectionDelegate())

  override func setUp() async throws {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral, mockPeripheral2])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start() {
      if state == .poweredOn {
        break
      }
    }
  }

  override func tearDown() {
    centralManager = nil
  }

  func test_scan_returnsDevices() async throws {
    let devices = try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
    for await device in devices {
      let id = await device.identifier
      XCTAssertEqual(id, mockPeripheral.identifier)
      break
    }
    for await device in devices {
      let id = await device.identifier
      XCTAssertEqual(id, mockPeripheral2.identifier)
      break
    }
  }

  func test_scan_throwsWhenCalledMultipleTimes() async throws {
    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          _ = try await self.centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
        }
        group.addTask {
          _ = try await self.centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service])
        }
        try await group.next()
        try await group.next()
      }
      XCTFail("Didn't throw")
    } catch {
      print(error)
      XCTAssertNotNil(error)
    }
  }

  func test_scan_endsScanWhenTaskIsCanceled() async throws {
    func assertAllScanning(_ expectedState: Bool = false) async throws {
      try await Task.sleep(nanoseconds: 1)
      try await Task.sleep(nanoseconds: 1)
      // Internal State
      let internalIsScanning = await centralManager.internalIsScanning
      XCTAssertEqual(internalIsScanning, expectedState, "internalIsScanning should be \(expectedState)")

      // Core Bluetooth state
      let isScanningCoreBLE = await centralManager.centralManager.isScanning
      XCTAssertEqual(isScanningCoreBLE, expectedState, "isScanningCoreBLE should be \(expectedState)")

      try await Task.sleep(nanoseconds: 1)
      // Public published state
      let isScanning = await centralManager.isScanning
      XCTAssertEqual(isScanning, expectedState, "isScanning should be \(expectedState)")
    }

    // false before scanning
    try await assertAllScanning(false)

    // true while scanning
    for await device in try await centralManager.scanForPeripherals(withServices: [MockPeripheral.UUIDs.Device.service]) {
      let id = await device.identifier
      XCTAssertEqual(id, mockPeripheral.identifier)
      try await assertAllScanning(true)
      break
    }

    // false after scanning is complete
    try await assertAllScanning(false)
  }
}
