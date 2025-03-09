//
//  ConnectionManagerView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//
import AsyncCoreBluetooth
import AsyncObservableUserDefaults
import CoreBluetooth
import SwiftUI

struct ConnectionManagerView: View {
  let centralManager: CentralManager
  let connectionManager: PeripheralConnectionManager
  @State private var showScanningPeripherals = false

  var body: some View {
    NavigationStack {
      VStack {
        if centralManager.bleState.observable != .poweredOn {
          BLEStateView(centralManager: centralManager)
        } else if UserDefaults.connectedDeviceId.observable == nil {
          VStack {
            Button(action: {
              showScanningPeripherals = true
            }) {
              Label("Start Scanning", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
          }
        } else if connectionManager.state.observable != .ready {
          ConnectingToPeripheralView(connectionManager: connectionManager) {
            Task {
              await connectionManager.stop()
              UserDefaults.connectedDeviceId.update(nil)
            }
          }
        } else {
          DeviceView(connectionManager: connectionManager)
        }
      }
      .padding()
      .navigationDestination(isPresented: $showScanningPeripherals) {
        ScanPeripheralsView(centralManager: centralManager) { selectedDevice in
          showScanningPeripherals = false
          let uuid = selectedDevice.state.identifier
          UserDefaults.connectedDeviceId.update(uuid.uuidString)
          Task {
            await connectionManager.manageConnection(peripheralUUID: uuid.uuidString)
          }
        }
      }
    }
  }
}
