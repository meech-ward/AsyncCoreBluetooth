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
      if let peripheral = connectionManager.peripheral, let heartRateMeasurementCharacteristic = connectionManager.heartRateMeasurementCharacteristic, let ledControlCharacteristic = connectionManager.ledControlCharacteristic {
        DeviceView(connectionManager: connectionManager, peripheral: peripheral, heartRateMeasurementCharacteristic: heartRateMeasurementCharacteristic, ledControlCharacteristic: ledControlCharacteristic)
      } else {
        ConnectionManagerView(centralManager: centralManager, connectionManager: connectionManager)
      }
    }
    .task {
#if targetEnvironment(simulator)
      MockPeripheral.setupFakePeripherals()
#endif
      // Mostly likely you want something like this
      // start BLE and connect to the device if it's already been connected to
      for await bleState in await centralManager.start() {
        if bleState == .poweredOn {
          await connectionManager.manageConnection(peripheralUUID: UserDefaults.connectedDeviceId.current)
        }
      }
    }
  }
}

#Preview {
  VStack {
    ContentView(centralManager: .init(forceMock: true))
  }.task {
    MockPeripheral.setupFakePeripherals()
  }
}
