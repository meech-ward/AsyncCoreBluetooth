//
//  DeviceView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Claude on 2025-03-08.
//

import AsyncCoreBluetooth
import CoreBluetooth
import SwiftUI

struct DeviceView: View {
  let connectionManager: PeripheralConnectionManager
  
  @State private var ledState: Bool = false
  @State private var heartRateNotificationsEnabled: Bool = false
    
  // MARK: - Computed Properties

  private var heartRateMeasurementCharacteristic: Characteristic? { connectionManager.heartRateMeasurementCharacteristic.observable }
  private var ledControlCharacteristic: Characteristic? { connectionManager.ledControlCharacteristic.observable }
  private var peripheral: Peripheral? { connectionManager.peripheral.observable }
    
  private var heartRate: Int? {
    guard let characteristic = heartRateMeasurementCharacteristic,
          let data = characteristic.value.observable
    else {
      return nil
    }
    return parseHeartRate(from: data)
  }
    
  private var deviceName: String {
    peripheral?.state.name ?? "Unknown Device"
  }
    
  private var deviceIdentifier: String {
    peripheral?.state.identifier.uuidString ?? ""
  }
    
  // MARK: - View Body
    
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        deviceHeader
        Divider()
        heartRateSection
        Divider()
        ledControlSection
        Spacer()
        disconnectButton
      }
      .padding()
      .navigationTitle("Connected Device")
    }
  }
    
  // MARK: - View Components
    
  private var deviceHeader: some View {
    VStack(spacing: 12) {
      Image(systemName: "antenna.radiowaves.left.and.right")
        .font(.system(size: 40))
        .foregroundColor(.green)
            
      Text(deviceName)
        .font(.title2)
        .fontWeight(.bold)
            
      if !deviceIdentifier.isEmpty {
        Text(deviceIdentifier)
          .font(.caption)
          .foregroundColor(.secondary)
      }
            
      HStack {
        Circle()
          .fill(Color.green)
          .frame(width: 10, height: 10)
                
        Text("Connected")
          .foregroundColor(.green)
          .font(.caption)
      }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.primary.opacity(0.05))
    .cornerRadius(12)
  }
    
  private var heartRateSection: some View {
    VStack(spacing: 16) {
      HStack {
        Image(systemName: "heart.fill")
          .foregroundColor(.red)
          .font(.title2)
                
        Text("Heart Rate")
          .font(.headline)
                
        Spacer()
                
        Toggle("Notifications", isOn: $heartRateNotificationsEnabled)
          .labelsHidden()
          .onChange(of: heartRateNotificationsEnabled) { _, newValue in
            Task {
              await toggleHeartRateNotifications(enabled: newValue)
            }
          }
      }
            
      HStack(alignment: .firstTextBaseline) {
        if let heartRate = heartRate {
          Text("\(heartRate)")
            .font(.system(size: 64, weight: .bold))
          Text("BPM")
            .font(.headline)
            .foregroundColor(.secondary)
        } else {
          Text("--")
            .font(.system(size: 64, weight: .bold))
            .foregroundColor(.secondary)
          Text("BPM")
            .font(.headline)
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical)
    }
    .padding()
    .background(Color.primary.opacity(0.05))
    .cornerRadius(12)
  }
    
  private var ledControlSection: some View {
    VStack(spacing: 16) {
      HStack {
        Image(systemName: "lightbulb.fill")
          .foregroundColor(ledState ? .yellow : .gray)
          .font(.title2)
                
        Text("LED Control")
          .font(.headline)
                
        Spacer()
                
        Toggle("LED", isOn: $ledState)
          .labelsHidden()
          .onChange(of: ledState) { _, newValue in
            Task {
              await toggleLED(on: newValue)
            }
          }
      }
            
      HStack {
        Text(ledState ? "ON" : "OFF")
          .fontWeight(.medium)
          .foregroundColor(ledState ? .green : .secondary)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical)
    }
    .padding()
    .background(Color.primary.opacity(0.05))
    .cornerRadius(12)
  }
    
  private var disconnectButton: some View {
    Button {
      Task {
        await connectionManager.stop()
      }
    } label: {
      HStack {
        Image(systemName: "eject.fill")
        Text("Disconnect")
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(Color.red.opacity(0.8))
      .foregroundColor(.white)
      .cornerRadius(10)
    }
  }
    
  // MARK: - BLE Actions
    
  private func toggleHeartRateNotifications(enabled: Bool) async {
    do {
      guard let peripheral, let heartRateMeasurementCharacteristic else {
        throw BLEError.characteristicNotAvailable
      }
            
      // The ESP32 implementation uses indications (BLE_GATT_CHR_F_INDICATE) for
      // the heart rate characteristic instead of notifications (BLE_GATT_CHR_F_NOTIFY)
      // However, AsyncCoreBluetooth uses the same API for both
      _ = try await peripheral.setNotifyValue(enabled, for: heartRateMeasurementCharacteristic)
      print("Successfully \(enabled ? "enabled" : "disabled") heart rate indications")
    } catch {
      print("Error toggling heart rate indications: \(error.localizedDescription)")
    }
  }
    
  private func toggleLED(on: Bool) async {
    do {
      guard let peripheral, let ledControlCharacteristic else {
        throw BLEError.characteristicNotAvailable
      }
            
      print("Setting LED state to: \(on ? "ON" : "OFF")")
            
      // This matches the ESP32 implementation that expects a single byte
      // with value 0 or 1 to control the LED state
      let data = Data([on ? UInt8(1) : UInt8(0)])
            
      // Using writeValueWithResponse to ensure the command was received correctly
      try await peripheral.writeValueWithResponse(data, for: ledControlCharacteristic)
      print("Successfully set LED to \(on ? "ON" : "OFF")")
            
    } catch {
      // the default esp code failes to return a valid rc so this might error here
      print("Error toggling LED: \(error.localizedDescription)")
    }
  }
    
  // Parse heart rate from the characteristic data according to Bluetooth Heart Rate Service specification
  private func parseHeartRate(from data: Data) -> Int? {
    guard !data.isEmpty else {
      print("Empty heart rate data received")
      return nil
    }
        
    let flags = data[0]
    let isFormat16Bit = (flags & 0x01) != 0
        
    if isFormat16Bit && data.count >= 3 {
      // 16-bit heart rate value (uncommon for simple implementations)
      let value = Int(data[1]) | (Int(data[2]) << 8)
      print("Parsed 16-bit heart rate: \(value) BPM")
      return value
    } else if data.count >= 2 {
      // 8-bit heart rate value (typical ESP32 implementation)
      // ESP32 implementation uses the standard Heart Rate Service (0x180D)
      // with Heart Rate Measurement characteristic (0x2A37)
      let value = Int(data[1])
      print("Parsed 8-bit heart rate: \(value) BPM")
      return value
    }
        
    print("Invalid heart rate data format")
    return nil
  }
}

// MARK: - Helper Types

enum BLEError: LocalizedError {
  case characteristicNotAvailable
  case ledWriteError
  case heartRateReadError
    
  var errorDescription: String? {
    switch self {
    case .characteristicNotAvailable:
      return "Peripheral characteristic not available"
    case .ledWriteError:
      return "Failed to write to LED control characteristic"
    case .heartRateReadError:
      return "Failed to read heart rate characteristic"
    }
  }
}

// MARK: - Preview

#Preview {
  // Mock setup for preview
  let centralManager = CentralManager(forceMock: true)
  let connectionManager = PeripheralConnectionManager(central: centralManager)
  return DeviceView(connectionManager: connectionManager)
}
