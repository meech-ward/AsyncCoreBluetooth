//
//  BLEStateView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//


import AsyncCoreBluetooth
import CoreBluetooth
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Show the current state of BLE on the device
/// This is just helpful for initial setup but probably won't be viewed much
struct BLEStateView: View {
  let centralManager: CentralManager
    
  var body: some View {
    VStack(spacing: 20) {
      Text("Bluetooth Status")
        .font(.largeTitle)
        .fontWeight(.bold)
        .padding(.top)
      
      // State indicator
      HStack {
        Image(systemName: iconName)
          .font(.system(size: 30))
          .foregroundColor(stateColor)
        
        Text(stateTitle)
          .font(.title3)
          .fontWeight(.semibold)
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(Color.primary.opacity(0.05))
      .cornerRadius(10)
      
      // Description
      Text(stateDescription)
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
      
      Spacer()
      
      // Settings button
      if centralManager.bleState.observable == .poweredOff {
        Button(action: openSettings) {
          Text("Open Bluetooth Settings")
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(.horizontal)
      }
    }
    .padding()
    .frame(maxWidth: 500)
    .task {
      await centralManager.start()
    }
  }
  
  // Simplified state properties
  private var iconName: String {
    switch centralManager.bleState.observable {
    case .poweredOn: return "network"
    case .poweredOff: return "network.slash"
    default: return "exclamationmark.circle"
    }
  }
  
  private var stateTitle: String {
    switch centralManager.bleState.observable {
    case .poweredOn: return "Bluetooth is On"
    case .poweredOff: return "Bluetooth is Off"
    default: return "Bluetooth Issue"
    }
  }
  
  private var stateDescription: String {
    switch centralManager.bleState.observable {
    case .poweredOn: return "Bluetooth is active and ready to connect."
    case .poweredOff: return "Please turn on Bluetooth in settings."
    case .unauthorized: return "Please allow Bluetooth access in settings."
    case .unsupported: return "This device doesn't support Bluetooth."
    case .resetting: return "Bluetooth is resetting..."
    default: return "There is an issue with Bluetooth."
    }
  }
  
  private var stateColor: Color {
    switch centralManager.bleState.observable {
    case .poweredOn: return .blue
    case .poweredOff: return .gray
    default: return .red
    }
  }
  
  // Platform-specific settings function
  private func openSettings() {
    #if os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.Bluetooth") {
      NSWorkspace.shared.open(url)
    } else {
      NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
    }
    #else
    if let url = URL(string: "App-Prefs:root=Bluetooth") {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
      } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL)
      }
    }
    #endif
  }
}

#Preview {
  BLEStateView(centralManager: .init(forceMock: true))
}
