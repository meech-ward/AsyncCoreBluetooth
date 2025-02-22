import SwiftUI
import AsyncCoreBluetooth

struct ScanningPeripherals: View {
  let heartRateServiceUUID = UUID(string: "180D")
  var centralManager: CentralManager
  @MainActor @State private var peripherals: Set<Peripheral> = []

  var body: some View {
    VStack {
      List(Array(peripherals), id: \.identifier) { peripheral in
        Section {
          ScannedPeripheralRow(centralManager: centralManager, peripheral: peripheral)
        }
      }
    }
    .task {
      do {
        for await peripheral in try await centralManager.scanForPeripherals(withServices: [heartRateServiceUUID]) {
          peripherals.insert(peripheral)
          // break out of the loop or terminate the continuation to stop the scan
        }
      } catch {
        // This only happens when ble state is not powered on or you're already scanning
        print("error scanning for peripherals \(error)")
      }
    }
  }
}