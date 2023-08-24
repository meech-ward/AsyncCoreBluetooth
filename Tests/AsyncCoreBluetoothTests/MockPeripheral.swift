import CoreBluetooth
import CoreBluetoothMock
import Foundation

class MockPeripheral {
  enum UUIDs {
    enum Device {
      static let service = CBUUID(string: "0xFFE0")
      static let message = UUID(uuidString: "a204a8f0-b16f-4c4e-84d2-59fc3f25962d")!
      static let deviceName = UUID(uuidString: "c9911d6a-08b3-4744-a877-8df12edb4e5e")!
    }
  }

  static let deviceService = CBMServiceMock(type: UUIDs.Device.service, primary: true)

  class Delegate: CBMPeripheralSpecDelegate {
    var peripheralDidReceiveConnectionRequestResult: Result<Void, Error>
    init(peripheralDidReceiveConnectionRequestResult: Result<Void, Error> = .success(())) {
      self.peripheralDidReceiveConnectionRequestResult = peripheralDidReceiveConnectionRequestResult
    }

    func peripheralDidReceiveConnectionRequest(_: CBMPeripheralSpec) -> Result<Void, Error> {
      return peripheralDidReceiveConnectionRequestResult
    }
  }

  static func makeDevice(delegate: CBMPeripheralSpecDelegate, isKnown: Bool = false) -> CBMPeripheralSpec {
    var spec = CBMPeripheralSpec
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

    if isKnown {
      spec = spec.allowForRetrieval()
    }

    return spec.build()
  }
}
