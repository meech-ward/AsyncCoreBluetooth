import AsyncCoreBluetooth
import AsyncObservableUserDefaults
import CoreBluetooth
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif



struct ContentView: View {
  let centralManager: CentralManager
  let connectionManager: PeripheralConnectionManager
  let connectedDeviceId: AsyncObservableUserDefaults<String?> = .init(key: "connectedDeviceId", initialValue: nil)
  @State private var showScanningPeripherals = false

  init(centralManager: CentralManager = .init()) {
    self.centralManager = centralManager
    connectionManager = PeripheralConnectionManager(central: centralManager)
  }

  var body: some View {
    NavigationStack {
      VStack {
        if centralManager.bleState.observable != .poweredOn {
          BLEStateView(centralManager: centralManager)
        } else if connectedDeviceId.observable == nil {
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
          ConnectingToPeripheralView(connectionManager: connectionManager)
        } else {
          Text("ready")
        }
      }
      .padding()
      .navigationDestination(isPresented: $showScanningPeripherals) {
        ScanPeripheralsView(centralManager: centralManager) { selectedDevice in
          showScanningPeripherals = false
          let uuid = selectedDevice.state.identifier
          connectedDeviceId.update(uuid.uuidString)
          Task {
            await connectionManager.manageConnection(peripheralUUID: uuid.uuidString)
          }
        }
      }
      .task {
        for await bleState in await centralManager.start() {
          if bleState == .poweredOn {
            await connectionManager.manageConnection(peripheralUUID: connectedDeviceId.current)
          }
        }
      }
    }
  }
}

#Preview {
  ContentView(centralManager: .init(forceMock: true))
}
