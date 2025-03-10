//
//  DeviceView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Claude on 2025-03-08.
//

import AsyncCoreBluetooth
import CoreBluetooth
import MightFail
import SwiftUI

struct DeviceView: View {
  @State private var ledState: Bool = false
  @State private var heartRateNotificationsEnabled: Bool = false
  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""
    
  let connectionManager: PeripheralConnectionManager
  let peripheral: Peripheral
  let heartRateMeasurementCharacteristic: Characteristic
  let ledControlCharacteristic: Characteristic
  
  // MARK: - Computed Properties

  private var heartRate: Int? {
    guard let data = heartRateMeasurementCharacteristic.value.observable else {
      return nil
    }
    return parseHeartRate(from: data)
  }
    
  private var deviceName: String {
    peripheral.name.observable ?? "No Name"
  }
    
  private var deviceIdentifier: String {
    peripheral.identifier.uuidString
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
      .alert("Error", isPresented: $showErrorAlert) {
        Button("OK") { showErrorAlert = false }
      } message: {
        Text(errorMessage)
      }
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
    // The ESP32 implementation uses indications (BLE_GATT_CHR_F_INDICATE) for
    // the heart rate characteristic instead of notifications (BLE_GATT_CHR_F_NOTIFY)
    // However, AsyncCoreBluetooth uses the same API for both
    let (error, _, success) = await mightFail { try await peripheral.setNotifyValue(enabled, for: heartRateMeasurementCharacteristic) }
    guard success else {
      let errorText = "Error toggling heart rate indications: \(error.localizedDescription)"
      print(errorText)
      
      errorMessage = errorText
      showErrorAlert = true
      // Revert toggle state since operation failed
      heartRateNotificationsEnabled = !enabled
      
      return
    }
    print("Successfully \(enabled ? "enabled" : "disabled") heart rate indications")
  }
    
  private func toggleLED(on: Bool) async {
    print("Setting LED state to: \(on ? "ON" : "OFF")")
            
    // This matches the ESP32 implementation that expects a single byte
    // with value 0 or 1 to control the LED state
    let data = Data([on ? UInt8(1) : UInt8(0)])
            
    // Using writeValueWithResponse to ensure the command was received correctly
    let (error, _, success) = await mightFail { try await peripheral.writeValueWithResponse(data, for: ledControlCharacteristic) }
    guard success else {
      let errorText = "Error toggling LED: \(error.localizedDescription)"
      print(errorText)

      errorMessage = errorText
      showErrorAlert = true
      // Revert toggle state since operation failed
      ledState = !on
      
      return
    }
    print("Successfully set LED to \(on ? "ON" : "OFF")")
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
