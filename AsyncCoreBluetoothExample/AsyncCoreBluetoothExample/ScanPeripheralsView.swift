//
//  ScanPeripheralsView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Claude on 2025-03-08.
//

import AsyncCoreBluetooth
import CoreBluetooth
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// A view that scans for and displays nearby BLE peripherals
/// Allows the user to view details and connect to peripherals
struct ScanPeripheralsView: View {
  let centralManager: CentralManager
  let selectDevice: (Peripheral) -> Void
    
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss
  
  @State private var peripherals: [Peripheral] = []
    
  var body: some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        Text("Scan for Devices")
          .font(.largeTitle)
          .fontWeight(.bold)
      }
            
      // Status indicator
      HStack {
        if centralManager.isScanning.observable {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(0.8)
                    
          Text("Scanning for devices...")
            .foregroundColor(.secondary)
        } else {
          Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundColor(.secondary)
                    
          Text(peripherals.isEmpty ? "Tap scan to find nearby devices" : "\(peripherals.count) devices found")
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.vertical, 10)
            
      // Error message (if any)
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 5)
      }
            
      // Peripherals list
      List {
        ForEach(peripherals, id: \.state.identifier) { peripheral in
          PeripheralRow(peripheral: peripheral)
            .contentShape(Rectangle())
            .onTapGesture {
              selectDevice(peripheral)
            }
        }
      }
      .listStyle(PlainListStyle())
    }
    .padding()
    .task {
      // if we call this version:
      // try await centralManager.scanForPeripherals(withServices: nil)
      // then we need to manually call centralManager.stopScan() when we're done
      // the following version stops the scane when the loop breaks
      // the loop breaks automatically when this task is canceled which happens when the view is dismissed

      do {
        // this peripheral doesn't advertise its services
        for await peripheral in try await centralManager.scanForPeripheralsStream(withServices: nil) {
          if peripheral.state.name == BLEIdentifiers.name {
            peripherals.append(peripheral)
          }
        }
      } catch {
        self.errorMessage = "Error scanning for peripherals: \(error.localizedDescription)"
      }
      print("scanning done")
    }
  }
}

/// A row displaying a peripheral's basic information
struct PeripheralRow: View {
  let peripheral: Peripheral
    
  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(peripheral.state.name ?? "Unknown Device")
          .font(.headline)
                
        Text(peripheral.state.identifier.uuidString)
          .font(.caption)
          .foregroundColor(.secondary)
      }
            
      Spacer()
            
      // Signal strength indicator
      Image(systemName: "dot.radiowaves.left.and.right")
        .foregroundColor(.blue)
    }
    .padding(.vertical, 8)
  }
}

#Preview {
  ScanPeripheralsView(centralManager: .init(forceMock: true), selectDevice: {_ in })
}
