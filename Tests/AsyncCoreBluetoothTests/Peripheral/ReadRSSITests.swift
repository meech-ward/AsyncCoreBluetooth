@preconcurrency import CoreBluetoothMock
import Foundation
import Testing

@testable import AsyncCoreBluetooth

@Suite(.serialized) struct ReadRSSITests {
  let mockPeripheralDelegate = MockPeripheral.Delegate()
  let rssiDeviation = 15
  
  func setup(proximity: CBMProximity, connect: Bool = true) async throws -> (Peripheral, CBMPeripheralSpec, CentralManager) {
    CBMCentralManagerMock.simulateInitialState(.poweredOff)

    // Create a mutable mockPeripheral
    let mockPeripheral = MockPeripheral.makeDevice(
      delegate: mockPeripheralDelegate,
      isKnown: true,
      proximity: proximity
    )

    CBMCentralManagerMock.simulatePeripherals([mockPeripheral])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)

    let centralManager = CentralManager(forceMock: true)
    _ = await centralManager.start().first(where: { $0 == .poweredOn })

    let peripheral = await centralManager.retrievePeripherals(withIdentifiers: [
      mockPeripheral.identifier
    ])[0]
    if connect {
      _ = await centralManager.connect(peripheral).first(where: { $0 == .connected })
    }
 
    return (peripheral, mockPeripheral, centralManager)
  }

  @Test("Read RSSI returns near proximity value")
  func test_readRSSI_near() async throws {
    let (peripheral, _, _) = try await setup(proximity: .near)

    try await peripheral.readRSSI()
    guard let rssiValue = await peripheral.rssi.stream.first(where: { _ in true }) else {
      Issue.record("No RSSI value received")
      return
    }
    // Near proximity base RSSI is -40, but can vary by ±15 (rssiDeviation)
    #expect(rssiValue >= -40 - rssiDeviation && rssiValue <= -40 + rssiDeviation)
  }

  @Test("Read RSSI returns immediate proximity value")
  func test_readRSSI_immediate() async throws {
    let (peripheral, _, _) = try await setup(proximity: .immediate)

    try await peripheral.readRSSI()
    guard let rssiValue = await peripheral.rssi.stream.first(where: { _ in true }) else {
      Issue.record("No RSSI value received")
      return
    }
    // Immediate proximity base RSSI is -70, but can vary by ±15 (rssiDeviation)
    #expect(rssiValue >= -70 - rssiDeviation && rssiValue <= -70 + rssiDeviation)
  }

  @Test("Read RSSI returns far proximity value")
  func test_readRSSI_far() async throws {
    let (peripheral, _, _) = try await setup(proximity: .far)

    try await peripheral.readRSSI()
    guard let rssiValue = await peripheral.rssi.stream.first(where: { _ in true }) else {
      Issue.record("No RSSI value received")
      return
    }
    // Far proximity base RSSI is -100, but can vary by ±15 (rssiDeviation)
    #expect(rssiValue >= -100 - rssiDeviation && rssiValue <= -100 + rssiDeviation)
  }

  @Test("RSSI Observable is initially nil")
  func test_rssi_initially_nil() async throws {
    let (peripheral, _, _) = try await setup(proximity: .near)
    
    // Before reading RSSI, the observable should be nil
    let initialValue = await peripheral._rssi.current
    #expect(initialValue == nil)
  }

  @Test("Multiple sequential RSSI reads return consistent values for the same proximity")
  func test_sequential_rssi_reads_consistent() async throws {
    let (peripheral, _, _) = try await setup(proximity: .near)
    
    // Read RSSI multiple times with the same proximity
    let rssi1 = try await peripheral.readRSSI()
    let rssi2 = try await peripheral.readRSSI()
    let rssi3 = try await peripheral.readRSSI()
    
    // All values should be near proximity (-40 ± deviation)
    #expect(rssi1 >= -40 - rssiDeviation && rssi1 <= -40 + rssiDeviation)
    #expect(rssi2 >= -40 - rssiDeviation && rssi2 <= -40 + rssiDeviation)
    #expect(rssi3 >= -40 - rssiDeviation && rssi3 <= -40 + rssiDeviation)
    
    // The observable should have the latest value
    let currentValue = await peripheral._rssi.current
    #expect(currentValue == rssi3)
  }
  
  @Test("RSSI observable updates when proximity changes")
  func test_rssi_updates_with_proximity_changes() async throws {
    // Start with near proximity
    let (peripheral, mockPeripheral, _) = try await setup(proximity: .near)
    
    // Read initial RSSI
    _ = try await peripheral.readRSSI()
    let initialRssi = await peripheral._rssi.current
    #expect(initialRssi != nil)
    #expect(initialRssi! >= -40 - rssiDeviation && initialRssi! <= -40 + rssiDeviation)
    
    // Change proximity to far and read again
    mockPeripheral.simulateProximityChange(.far)
    _ = try await peripheral.readRSSI()
    
    // RSSI should update to far proximity value
    let farRssi = await peripheral._rssi.current
    #expect(farRssi != nil)
    #expect(farRssi! >= -100 - rssiDeviation && farRssi! <= -100 + rssiDeviation)
  }
  
  @Test("RSSI stream receives updates")
  func test_rssi_stream_receives_updates() async throws {
    let (peripheral, mockPeripheral, _) = try await setup(proximity: .near)
    
    // Get initial RSSI value
    _ = try await peripheral.readRSSI()
    let firstValue = await peripheral._rssi.current
    #expect(firstValue != nil)
    #expect(firstValue! >= -40 - rssiDeviation && firstValue! <= -40 + rssiDeviation)
    
    // Change to immediate proximity and read
    mockPeripheral.simulateProximityChange(.immediate)
    _ = try await peripheral.readRSSI()
    let secondValue = await peripheral._rssi.current
    #expect(secondValue != nil)
    #expect(secondValue! >= -70 - rssiDeviation && secondValue! <= -70 + rssiDeviation)
    
    // Change to far proximity and read
    mockPeripheral.simulateProximityChange(.far)
    _ = try await peripheral.readRSSI()
    let thirdValue = await peripheral._rssi.current
    #expect(thirdValue != nil)
    #expect(thirdValue! >= -100 - rssiDeviation && thirdValue! <= -100 + rssiDeviation)
  }
  
  @Test("RSSI values can be collected with AsyncStream")
  func test_rssi_values_collected_with_stream() async throws {
    let (peripheral, mockPeripheral, _) = try await setup(proximity: .near)
    
    // Create a task to collect RSSI values from the stream
    let streamTask = Task {
      var values = [Int]()
      var count = 0
      for await value in await peripheral.rssi.stream {
        values.append(value)
        count += 1
        if count >= 3 {
          // We'll collect 3 values
          break
        }
      }
      return values
    }
    
    // Now perform real RSSI reads with different proximities to generate values
    _ = try await peripheral.readRSSI() // Read with near proximity
    
    // Change to immediate proximity and read again
    mockPeripheral.simulateProximityChange(.immediate)
    _ = try await peripheral.readRSSI()
    
    // Change to far proximity and read again
    mockPeripheral.simulateProximityChange(.far)
    _ = try await peripheral.readRSSI()
    
    // Get the collected values from our stream task
    let collectedValues = await streamTask.value
    
    // Verify the stream collected all three values
    #expect(collectedValues.count == 3)
    
    // Verify values match the expected proximity ranges
    #expect(collectedValues[0] >= -40 - rssiDeviation && collectedValues[0] <= -40 + rssiDeviation) // Near
    #expect(collectedValues[1] >= -70 - rssiDeviation && collectedValues[1] <= -70 + rssiDeviation) // Immediate
    #expect(collectedValues[2] >= -100 - rssiDeviation && collectedValues[2] <= -100 + rssiDeviation) // Far
  }
  
  // @Test("Disconnected peripheral throws error on RSSI read")
  // func test_disconnected_peripheral_throws_error() async throws {
  //   let (peripheral, _, centralManager) = try await setup(proximity: .near)
  //   await centralManager.cancelPeripheralConnection(peripheral)
    
  //   // Attempt to read RSSI, should throw an error
  //   do {
  //     _ = try await peripheral.readRSSI()
  //     Issue.record("Expected an error when reading RSSI from disconnected peripheral")
  //   } catch {
  //     // Expected to throw an error
  //     #expect(error is PeripheralConnectionError)
  //   }
  // }
}
