//
//  ConnectingToPeripheralView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//

import SwiftUI

struct ConnectingToPeripheralView: View {
  let connectionManager: PeripheralConnectionManager
  let removeDevice: () -> Void
    
  var body: some View {
    VStack(spacing: 16) {
      connectionStateView
    }
    .padding()
    .frame(maxWidth: .infinity)
    .cornerRadius(12)
    .shadow(radius: 2)
    .padding()
  }
    
  @ViewBuilder
  private var connectionStateView: some View {
    if case .error(let error) = connectionManager.state.observable {
      statusView(
        icon: "exclamationmark.triangle",
        title: "Connection Error",
        message: error.localizedDescription,
        color: .red
      )
    }
    if let peripheral = connectionManager.peripheral.observable {
      switch peripheral.state.connectionState {
      case .disconnected(let cBError):
        statusView(
          icon: "wifi.slash",
          title: "Disconnected",
          message: cBError?.localizedDescription ?? "No error description",
          color: .orange
        )
        reconnectButton
                
      case .connecting:
        statusView(
          icon: "antenna.radiowaves.left.and.right",
          title: "Connecting",
          message: "Please wait...",
          color: .blue
        )
                
      case .connected:
        statusView(
          icon: "checkmark.circle",
          title: "Connected",
          message: "Device connected successfully",
          color: .green
        )
                
      case .disconnecting:
        statusView(
          icon: "wifi.exclamationmark",
          title: "Disconnecting",
          message: "Please wait...",
          color: .orange
        )
                
      case .failedToConnect(let cBError):
        statusView(
          icon: "xmark.circle",
          title: "Connection Failed",
          message: "\(cBError)",
          color: .red
        )
        reconnectButton
      }
      removeDeviceButton
    }
  }
    
  private func statusView(icon: String, title: String, message: String, color: Color) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundColor(color)
            
      Text(title)
        .font(.headline)
            
      Text(message)
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
    }
  }
    
  private var reconnectButton: some View {
    Button {
      Task {
        if let peripheral = connectionManager.peripheral.observable {
          await connectionManager.manageConnection(peripheralUUID: peripheral.identifier.uuidString)
        }
      }
    } label: {
      Label("Reconnect", systemImage: "arrow.clockwise")
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    .padding(.top, 8)
  }
  
  private var removeDeviceButton: some View {
    Button {
      removeDevice()
    } label: {
      Label("Remove Device", systemImage: "trash.circle")
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    .padding(.top, 8)
  }
}
