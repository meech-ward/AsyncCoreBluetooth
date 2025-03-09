import CoreBluetoothMock
import Foundation

class MockPeripheral {
  static let deviceService = CBMServiceMock(type: UUIDs.Device.service, primary: true)

  class SuccessConnectionDelegate: CBMPeripheralSpecDelegate {
    func peripheralDidReceiveConnectionRequest(_: CBMPeripheralSpec) -> Result<Void, Error> {
      return .success(())
    }
  }

  class FailureConnectionDelegate: CBMPeripheralSpecDelegate {
    func peripheralDidReceiveConnectionRequest(_: CBMPeripheralSpec) -> Result<Void, Error> {
      return .failure(CBMError(.connectionFailed))
    }
  }

  static func makeDevice(name: String = "my device", delegate: CBMPeripheralSpecDelegate) -> CBMPeripheralSpec {
    CBMPeripheralSpec
      .simulatePeripheral(proximity: .near)
      .advertising(
        advertisementData: [
          CBMAdvertisementDataLocalNameKey: name,
          CBMAdvertisementDataServiceUUIDsKey: [deviceService.uuid],
          CBMAdvertisementDataIsConnectable: true as NSNumber,
        ],
        withInterval: 0.250
      )
      .connectable(
        name: name,
        services: [deviceService],
        delegate: delegate,
        connectionInterval: 0.045,
        mtu: 23
      )
      .build()
  }

  static func setupFakePeripherals() {
    lazy var mockPeripheral1: CBMPeripheralSpec = MockPeripheral.makeDevice(name: "My Device 1", delegate: MockPeripheral.SuccessConnectionDelegate())
    lazy var mockPeripheral2: CBMPeripheralSpec = MockPeripheral.makeDevice(name: "My Device 2", delegate: MockPeripheral.SuccessConnectionDelegate())

    CBMCentralManagerMock.simulateInitialState(.poweredOff)
    CBMCentralManagerMock.simulatePeripherals([mockPeripheral1, mockPeripheral2])
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
  }
}