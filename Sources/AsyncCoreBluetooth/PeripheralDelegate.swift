import CoreBluetoothMock
import Foundation

// CBMPeripheralDelegate
extension Peripheral {
  func peripheralDidUpdateName(_ peripheral: CBMPeripheral) {
    print("peripheralDidUpdateName \(peripheral)")
  }

  func peripheral(_ peripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]) {
    print("peripheral \(peripheral) didModifyServices \(invalidatedServices)")
  }

  func peripheral(_ peripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    print("peripheral \(peripheral) didReadRSSI \(RSSI) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverServices error: Error?) {
    print("peripheral \(peripheral) didDiscoverServices \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?) {
    print("peripheral \(peripheral) didDiscoverIncludedServicesFor \(service) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?) {
    print("peripheral \(peripheral) didDiscoverCharacteristicsFor \(service) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(peripheral) didUpdateValueFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(peripheral) didWriteValueFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(peripheral) didUpdateNotificationStateFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic, error: Error?) {
    print("peripheral \(peripheral) didDiscoverDescriptorsFor \(characteristic) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?) {
    print("peripheral \(peripheral) didUpdateValueFor \(descriptor) error \(String(describing: error))")
  }

  func peripheral(_ peripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?) {
    print("peripheral \(peripheral) didWriteValueFor \(descriptor) error \(String(describing: error))")
  }

  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBMPeripheral) {
    print("peripheralIsReadyToSendWriteWithoutResponse \(peripheral)")
  }

  func peripheral(_ peripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    print("peripheral \(peripheral) didOpen \(String(describing: channel)) error \(String(describing: error))")
  }
}

class PeripheralDelegate: NSObject, CBMPeripheralDelegate {
  let peripheral: Peripheral
  init(peripheral: Peripheral) {
    self.peripheral = peripheral
  }

  func peripheralDidUpdateName(_ peripheral: CBMPeripheral) {
    Task {
      await self.peripheral.peripheralDidUpdateName(peripheral)
      peripheral.delegate?.peripheralDidUpdateName(peripheral)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]) {
    Task {
      await self.peripheral.peripheral(peripheral, didModifyServices: invalidatedServices)
      peripheral.delegate?.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didReadRSSI: RSSI, error: error)
      peripheral.delegate?.peripheral(peripheral, didReadRSSI: RSSI, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverServices error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didDiscoverServices: error)
      peripheral.delegate?.peripheral(peripheral, didDiscoverServices: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didDiscoverIncludedServicesFor: service, error: error)
      peripheral.delegate?.peripheral(peripheral, didDiscoverIncludedServicesFor: service, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
      peripheral.delegate?.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
      peripheral.delegate?.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
      peripheral.delegate?.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
      peripheral.delegate?.peripheral(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didUpdateValueFor: descriptor, error: error)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: descriptor, error: error)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didWriteValueFor: descriptor, error: error)
      peripheral.delegate?.peripheral(peripheral, didWriteValueFor: descriptor, error: error)
    }
  }

  func peripheralIsReadyToSendWriteWithoutResponse(_ peripheral: CBMPeripheral) {
    Task {
      await self.peripheral.peripheralIsReady(toSendWriteWithoutResponse: peripheral)
      peripheral.delegate?.peripheralIsReady(toSendWriteWithoutResponse: peripheral)
    }
  }

  func peripheral(_ peripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    Task {
      await self.peripheral.peripheral(peripheral, didOpen: channel, error: error)
      peripheral.delegate?.peripheral(peripheral, didOpen: channel, error: error)
    }
  }
}
