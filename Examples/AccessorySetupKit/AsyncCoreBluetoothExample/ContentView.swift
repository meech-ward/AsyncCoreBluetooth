import AsyncCoreBluetooth
import AsyncObservableUserDefaults
import CoreBluetooth
import MightFail
import SwiftUI

struct ContentView: View {
  let centralManager: CentralManager
  let connectionManager: PeripheralConnectionManager
  let accessoryManager: AccessoryManager

  init(centralManager: CentralManager = .init(), accessoryManager: AccessoryManager = .init()) {
    print("content view created")
    self.centralManager = centralManager
    self.accessoryManager = accessoryManager
    connectionManager = PeripheralConnectionManager(central: centralManager)
  }

  var body: some View {
    VStack {
      if let peripheral = connectionManager.peripheral, let heartRateMeasurementCharacteristic = connectionManager.heartRateMeasurementCharacteristic, let ledControlCharacteristic = connectionManager.ledControlCharacteristic {
        DeviceView(connectionManager: connectionManager, peripheral: peripheral, heartRateMeasurementCharacteristic: heartRateMeasurementCharacteristic, ledControlCharacteristic: ledControlCharacteristic)
      } else {
        ConnectionManagerView(centralManager: centralManager, connectionManager: connectionManager, accessoryManager: accessoryManager)
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
