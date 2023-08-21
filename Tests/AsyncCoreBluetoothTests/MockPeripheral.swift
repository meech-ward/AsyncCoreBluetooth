import CoreBluetoothMock
import Foundation

class MockPeripheral {
  enum UUIDs {
    enum Device {
      static let service = UUID(uuidString: "b42d0f5c-e935-4be8-85ae-73b998e682f7")!
      static let message = UUID(uuidString: "a204a8f0-b16f-4c4e-84d2-59fc3f25962d")!
      static let deviceName = UUID(uuidString: "c9911d6a-08b3-4744-a877-8df12edb4e5e")!
    }
  }

  static let deviceService = CBMServiceMock(type: CBMUUID(nsuuid: UUIDs.Device.service), primary: true)

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

  static func makeDevice(delegate: CBMPeripheralSpecDelegate) -> CBMPeripheralSpec {
    CBMPeripheralSpec
      .simulatePeripheral(proximity: .near)
      .advertising(
        advertisementData: [
          CBMAdvertisementDataLocalNameKey: "my device",
          CBMAdvertisementDataServiceUUIDsKey: [deviceService.uuid],
          CBMAdvertisementDataIsConnectable: true as NSNumber,
        ],
        withInterval: 0.250
      )
      .connectable(
        name: "my device",
        services: [deviceService],
        delegate: delegate,
        connectionInterval: 0.045,
        mtu: 23
      )
      .build()
  }
}
