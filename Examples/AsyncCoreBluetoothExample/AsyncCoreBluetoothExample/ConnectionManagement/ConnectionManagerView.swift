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
        } else {
          ConnectingToPeripheralView(connectionManager: connectionManager) {
            Task {
              await connectionManager.stop()
              UserDefaults.connectedDeviceId.update(nil)
            }
          }
        }
      }
      .padding()
      .navigationDestination(isPresented: $showScanningPeripherals) {
        ScanPeripheralsView(centralManager: centralManager) { selectedDevice in
          showScanningPeripherals = false
          let uuid = selectedDevice.identifier
          UserDefaults.connectedDeviceId.update(uuid.uuidString)
          Task {
            await connectionManager.manageConnection(peripheralUUID: uuid.uuidString)
          }
        }
      }
    }
  }
}

#Preview {
  MockPeripheral.setupFakePeripherals()

  return ConnectionManagerView(centralManager: .init(forceMock: true), connectionManager: PeripheralConnectionManager(central: .init(forceMock: true)))
    .task {}
}
