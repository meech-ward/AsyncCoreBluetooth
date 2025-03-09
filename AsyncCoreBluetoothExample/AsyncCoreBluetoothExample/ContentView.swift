import AsyncCoreBluetooth
import AsyncObservableUserDefaults
import CoreBluetooth
import SwiftUI

struct ContentView: View {
  let centralManager: CentralManager
  let connectionManager: PeripheralConnectionManager

  init(centralManager: CentralManager = .init()) {
    print("content view created")
    self.centralManager = centralManager
    connectionManager = PeripheralConnectionManager(central: centralManager)
  }

  var body: some View {
    VStack {
      if connectionManager.state.observable != .ready {
        ConnectionManagerView(centralManager: centralManager, connectionManager: connectionManager)
      } else {
        DeviceView(connectionManager: connectionManager)
      }
    }
    .task {
      for await bleState in await centralManager.start() {
        if bleState == .poweredOn {
          await connectionManager.manageConnection(peripheralUUID: UserDefaults.connectedDeviceId.current)
        }
      }
    }
  }
}

#Preview {
  ContentView(centralManager: .init(forceMock: true))
}
