import CoreBluetoothMock
import Foundation
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct ScanForNewPeripheralsTests {
  var centralManager: CentralManager!

  var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate()
  )
  var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(
    delegate: MockPeripheral.Delegate()
  )

  init() async throws {
    print("init")
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral, mockPeripheral2, mockPeripheral, mockPeripheral2, mockPeripheral, mockPeripheral2])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start() {
      if state == .poweredOn {
        break
      }
    }
  }

  @Test("Scan returns devices")
  func testScanReturnsDevices() async throws {
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
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
    func assertAllScanning(_ expectedState: Bool = false, message: String = "") async throws {
      try await Task.sleep(nanoseconds: 1)
      try await Task.sleep(nanoseconds: 1)

      // Internal State
      let internalIsScanning = await centralManager.isScanning.current
      #expect(
        internalIsScanning == expectedState,
        "internalIsScanning should be \(expectedState) \(message)"
      )

      // Core Bluetooth state
      let isScanningCoreBLE = await centralManager.centralManager.isScanning
      #expect(
        isScanningCoreBLE == expectedState,
        "isScanningCoreBLE should be \(expectedState) \(message)"
      )

      try await Task.sleep(nanoseconds: 1)
      // Public published state
      let isScanning = await centralManager.isScanning.current
      #expect(
        isScanning == expectedState,
        "isScanning should be \(expectedState) \(message)"
      )
    }

    // false before scanning
    try await assertAllScanning(false, message: "before scanning")

    // true while scanning
    for await _ in try await centralManager.scanForPeripheralsStream(withServices: [MockPeripheral.UUIDs.Device.service]) {
      try await assertAllScanning(true, message: "while scanning")
      break
    }

    try await Task.sleep(for: .milliseconds(100))

    // false after scanning is complete
    try await assertAllScanning(false, message: "after scanning is complete")
  }
}
@Suite(.serialized) struct ScanForNewPeripheralsWithoutDuplicatesTests {
  var centralManager: CentralManager!

  var mockPeripheral: CBMPeripheralSpec = MockPeripheral.makeDevice(
    identifier: UUID(uuidString: "12345678-1234-5678-1234-567812345678")!,
    delegate: MockPeripheral.Delegate()
  )
  var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(
    identifier: UUID(uuidString: "12345678-1234-5678-1234-567812345679")!,
    delegate: MockPeripheral.Delegate()
  )
  var mockPeripheral3: CBMPeripheralSpec = MockPeripheral.makeDevice(
    identifier: UUID(uuidString: "12345678-1234-5678-1234-567812345678")!,
    delegate: MockPeripheral.Delegate()
  )

  var mockPeripheral4: CBMPeripheralSpec = MockPeripheral.makeDevice(
    identifier: UUID(uuidString: "12345678-1234-5678-1234-567812345678")!,
    delegate: MockPeripheral.Delegate()
  )
  var mockPeripheral5: CBMPeripheralSpec = MockPeripheral.makeDevice(
    identifier: UUID(uuidString: "12345678-1234-5678-1234-567812345679")!,
    delegate: MockPeripheral.Delegate()
  )
  init() async throws {
    print("init")
    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral, mockPeripheral2, mockPeripheral3, mockPeripheral4, mockPeripheral5, mockPeripheral, mockPeripheral2, mockPeripheral3, mockPeripheral4, mockPeripheral5])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    centralManager = CentralManager(forceMock: true)
    for await state in await centralManager.start() {
      if state == .poweredOn {
        break
      }
    }
  }

  @Test("Scan detects the same peripheral only once")
  func testScanDetectsPeripheralOnlyOnce() async throws {
    // Create a counter to track how many times we see the peripheral
    var deviceCount = 0

    // Start the scan
    let devices = try await centralManager.scanForPeripheralsStream(withServices: [
      MockPeripheral.UUIDs.Device.service
    ])

    // Iterate through results with a timeout to avoid infinite waiting
    var streamIds = Set<UUID>()
    let task = Task {
      for await device in devices {
        print("device: \(await device.identifier)")
        streamIds.insert(await device.identifier)
        deviceCount += 1
      }
    }

    // Give some time for the scan to complete and find all peripherals
    try await Task.sleep(for: .milliseconds(1000))
    task.cancel()

    // Verify we only saw each unique peripheral once in the stream
    #expect(deviceCount == 2, "The stream should only yield each unique peripheral once")

    // Also verify the peripheralsScanned property contains the correct number of unique peripherals
    let scannedDevices = await centralManager.peripheralsScanned.current
    #expect(scannedDevices.count == 2, "The peripheralsScanned property should contain only unique peripherals")

    var scannedIds = Set<UUID>()
    for device in scannedDevices {
      scannedIds.insert(await device.identifier)
    }

    // Check that the identifiers in peripheralsScanned match our expected peripherals
    let expectedIds = Set([mockPeripheral.identifier, mockPeripheral2.identifier])
    #expect(scannedIds == expectedIds, "The peripheralsScanned should contain the expected peripheral identifiers")
    #expect(streamIds == expectedIds, "The stream should contain the expected peripheral identifiers")
  }
}
