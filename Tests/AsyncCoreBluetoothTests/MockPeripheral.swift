import CoreBluetooth
import CoreBluetoothMock
import Foundation

class MockPeripheral: @unchecked Sendable {
  enum UUIDs: Sendable {
    enum Device: Sendable {
      static let service = CBUUID(string: "0xFFE0")
      static let characteristic = CBUUID(string: "0xFFE1")
      static let descriptor = CBUUID(string: "0xFFE2")
      static let message = UUID(uuidString: "a204a8f0-b16f-4c4e-84d2-59fc3f25962d")!
      static let deviceName = UUID(uuidString: "c9911d6a-08b3-4744-a877-8df12edb4e5e")!
    }
  }

  static let deviceCharacteristic = CBMCharacteristicMock(type: UUIDs.Device.characteristic, properties: [.read, .write, .notify], descriptors: CBMDescriptorMock(type: UUIDs.Device.descriptor))

  static let deviceService = CBMServiceMock(type: UUIDs.Device.service, primary: true, characteristics: [deviceCharacteristic])

  class Delegate: CBMPeripheralSpecDelegate {
    var readData: Data?
    var peripheralDidReceiveConnectionRequestResult: Result<Void, Error>
    init(peripheralDidReceiveConnectionRequestResult: Result<Void, Error> = .success(())) {
      self.peripheralDidReceiveConnectionRequestResult = peripheralDidReceiveConnectionRequestResult
    }

    func peripheralDidReceiveConnectionRequest(_: CBMPeripheralSpec) -> Result<Void, Error> {
      return peripheralDidReceiveConnectionRequestResult
    }
    
    // Read requests
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveReadRequestFor characteristic: CBMCharacteristicMock) -> Result<Data, Error> {
        return .success(readData ?? Data())
    }
    
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveReadRequestFor descriptor: CBMDescriptorMock) -> Result<Data, Error> {
        return .success(readData ?? Data())
    }
    
    // Write requests
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveWriteRequestFor characteristic: CBMCharacteristicMock, 
                   data: Data) -> Result<Void, Error> {
        return .success(())
    }
    
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveWriteCommandFor characteristic: CBMCharacteristicMock, 
                   data: Data) {
        // No return value needed for write without response
    }
    
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveWriteRequestFor descriptor: CBMDescriptorMock, 
                   data: Data) -> Result<Void, Error> {
        return .success(())
    }
    
    // Notification handling
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didReceiveSetNotifyRequest enabled: Bool, 
                   for characteristic: CBMCharacteristicMock) -> Result<Void, Error> {
        return .success(())
    }
    
    func peripheral(_ peripheral: CBMPeripheralSpec, 
                   didUpdateNotificationStateFor characteristic: CBMCharacteristicMock, 
                   error: Error?) {
        // No return value needed
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
