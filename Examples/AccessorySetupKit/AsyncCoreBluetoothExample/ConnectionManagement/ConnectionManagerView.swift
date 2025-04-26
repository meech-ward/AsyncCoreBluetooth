//
//  ConnectionManagerView.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//
import AccessorySetupKit
import AsyncCoreBluetooth
import AsyncObservableUserDefaults
import CoreBluetooth
import MightFail
import SwiftUI

struct ConnectionManagerView: View {
  let centralManager: CentralManager
  let connectionManager: PeripheralConnectionManager
  let accessoryManager: AccessoryManager
  @State var hasAccessory = false

  @State private var showErrorAlert = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack {
        if hasAccessory == false {
          VStack {
            Button(action: {
              showAccessoryPicker()
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
        } else if centralManager.bleState.observable != .poweredOn {
          BLEStateView(centralManager: centralManager)
        } else {
          ConnectingToPeripheralView(connectionManager: connectionManager) {
            Task {
              await connectionManager.stop()
            }
          }
        }
      }
      .padding()
      .alert(isPresented: $showErrorAlert) {
        Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
      }
    }
    .task {
      if let accessory = accessoryManager.accessory.current {
        hasAccessory = true
        // they probably manually disconeected to get here
        // so well let them reconnect manually
        // there won't be an accessory here when they first launch the app
        return
      }
      
      
      let (accessoryError, _, success) = await mightFail {
        try await accessoryManager.activateSessionIfNotActivated()
      }
      guard success else {
        print("Error activating session: \(accessoryError.localizedDescription)")
        return
      }
      for await accessory in accessoryManager.accessory.stream {
        if let accessory {
          hasAccessory = true
          await connectToAccessory(accessory)
        } else {
          hasAccessory = false
        }
      }
    }
  }

  private func showAccessoryPicker() {
    Task {
      let (error, accessory) = await mightFail { try await accessoryManager.showPicker() }
      if let error {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        return
      }
      guard let accessory else {
        errorMessage = "Could not get accessory"
        showErrorAlert = true
        return
      }
      await connectToAccessory(accessory)
    }
  }

  private func connectToAccessory(_ accessory: ASAccessory) async {
    hasAccessory = true
    for await bleState in await centralManager.start() {
      if case .poweredOn = bleState {
        break
      }
    }
    await connectionManager.manageConnection(peripheralUUID: accessory.bluetoothIdentifier)
  }
}

#Preview {
  ConnectionManagerView(centralManager: .init(forceMock: true), connectionManager: PeripheralConnectionManager(central: .init(forceMock: true)), accessoryManager: .init())
    .task { MockPeripheral.setupFakePeripherals() }
}
