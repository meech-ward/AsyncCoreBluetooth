import Foundation

actor PeripheralStore {
  static let shared = PeripheralStore()

  private var storedPeripherals: [UUID: Peripheral] = [:]

  private init() {}

  func store(_ peripheral: Peripheral, for uuid: UUID) {
    storedPeripherals[uuid] = peripheral
  }

  func getPeripheral(for uuid: UUID) -> Peripheral? {
    storedPeripherals[uuid]
  }
}
