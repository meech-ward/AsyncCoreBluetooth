import SwiftUI
import AsyncCoreBluetooth

struct ContentView: View {
  var centralManager = CentralManager()
  var body: some View {
    NavigationStack {
      VStack {
        switch centralManager.state.bleState {
        case .unknown:
          Text("Unkown")
        case .resetting:
          Text("Resetting")
        case .unsupported:
          Text("Unsupported")
        case .unauthorized:
          Text("Unauthorized")
        case .poweredOff:
          Text("Powered Off")
        case .poweredOn:
            Text("Powered On, ready to scan")
        }
      }
      .padding()
      .navigationTitle("App")
    }
    .task {
      await centralManager.start()
      // or startStream if you want the async stream returned from start
    }
  }
}