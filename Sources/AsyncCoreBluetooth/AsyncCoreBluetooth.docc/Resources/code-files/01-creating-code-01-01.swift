import Foundation
import CoreBluetooth
import AsyncCoreBluetooth

actor MyAppsBLEManager {
  let centralManager = CentralManager()

  func start() async {
    for await bleState in await centralManager.startStream() {
      switch bleState {
      case .unknown:
        print("Unkown")
      case .resetting:
        print("Resetting")
      case .unsupported:
        print("Unsupported")
      case .unauthorized:
        print("Unauthorized")
      case .poweredOff:
        print("Powered Off")
      case .poweredOn:
        print("Powered On, ready to scan")
      }
    }
  }
}
