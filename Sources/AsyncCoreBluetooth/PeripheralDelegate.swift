import CoreBluetoothMock
import Foundation

// CBMPeripheralDelegate
extension Peripheral {
  func peripheralDidUpdateName(_ cbPeripheral: CBMPeripheral) {
    print("peripheralDidUpdateName \(cbPeripheral)")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]) {
    print("peripheral \(cbPeripheral) didModifyServices \(invalidatedServices)")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    print("peripheral \(cbPeripheral) didReadRSSI \(RSSI) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverServices error: Error?) {
    guard let services = cbPeripheral.services else {
      return
    }
    print("peripheral \(cbPeripheral) didDiscoverServices \(String(describing: error))")
    print(services)
    print(services.map { $0.uuid })
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?) {
    print("peripheral \(cbPeripheral) didDiscoverIncludedServicesFor \(service) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?) {
    print("peripheral \(cbPeripheral) didDiscoverCharacteristicsFor \(service) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(cbPeripheral) didUpdateValueFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(cbPeripheral) didWriteValueFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(cbPeripheral) didUpdateNotificationStateFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(cbPeripheral) didDiscoverDescriptorsFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?) {
    print("peripheral \(cbPeripheral) didUpdateValueFor \(descriptor) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?) {
    print("peripheral \(cbPeripheral) didWriteValueFor \(descriptor) error \(String(describing: error))")
  }

  func peripheralIsReady(toSendWriteWithoutResponse cbPeripheral: CBMPeripheral) {
    print("peripheralIsReadyToSendWriteWithoutResponse \(cbPeripheral)")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    print("peripheral \(cbPeripheral) didOpen \(String(describing: channel)) error \(String(describing: error))")
  }
}

class PeripheralDelegate: NSObject, CBMPeripheralDelegate {
  let peripheral: Peripheral
  init(peripheral: Peripheral) {
    self.peripheral = peripheral
  }

  func peripheralDidUpdateName(_ cbPeripheral: CBMPeripheral) {
    Task {
      await peripheral.peripheralDidUpdateName(cbPeripheral)
      await await peripheral.delegate?.peripheralDidUpdateName(cbPeripheral)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]) {
    Task {
      await peripheral.peripheral(cbPeripheral, didModifyServices: invalidatedServices)
      await peripheral.delegate?.peripheral(cbPeripheral, didModifyServices: invalidatedServices)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didReadRSSI: RSSI, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didReadRSSI: RSSI, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverServices error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didDiscoverServices: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didDiscoverServices: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didDiscoverIncludedServicesFor: service, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didDiscoverIncludedServicesFor: service, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didDiscoverCharacteristicsFor: service, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didUpdateValueFor: characteristic, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didWriteValueFor: characteristic, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateNotificationStateFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didUpdateNotificationStateFor: characteristic, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didDiscoverDescriptorsFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didDiscoverDescriptorsFor: characteristic, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: descriptor, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didUpdateValueFor: descriptor, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: descriptor, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didWriteValueFor: descriptor, error: error)
    }
  }

  func peripheralIsReadyToSendWriteWithoutResponse(_ cbPeripheral: CBMPeripheral) {
    Task {
      await peripheral.peripheralIsReady(toSendWriteWithoutResponse: cbPeripheral)
      await peripheral.delegate?.peripheralIsReady(toSendWriteWithoutResponse: cbPeripheral)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didOpen: channel, error: error)
      await peripheral.delegate?.peripheral(cbPeripheral, didOpen: channel, error: error)
    }
  }
}
