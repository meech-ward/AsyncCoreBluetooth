@preconcurrency import CoreBluetoothMock
import Foundation

// CBMPeripheralDelegate
extension Peripheral {
  func peripheralDidUpdateName(_ cbPeripheral: CBMPeripheral) {
    print("peripheralDidUpdateName \(cbPeripheral)")
    delegate?.peripheralDidUpdateName(cbPeripheral)
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]
  ) {
    print("peripheral \(cbPeripheral) didModifyServices \(invalidatedServices)")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    print("peripheral \(cbPeripheral) didReadRSSI \(RSSI) error \(String(describing: error))")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverServices error: Error?) async {
    guard let cbServices = cbPeripheral.services else {
      return
    }
    var services = [Service]()
    for cbService in cbServices {
      let service = await Service(service: cbService, peripheral: self)
      services.append(service)
    }

    delegate?.peripheral(cbPeripheral, didDiscoverServices: error)
    self.services = services
    discoverServicesContinuations.forEach { $0.resume(with: Result.success(services)) }
    discoverServicesContinuations = []
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didDiscoverIncludedServicesFor \(service) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverCharacteristicsFor cbmService: CBMService,
    error: Error?
  ) async {
    guard let cbCharacteristics = cbmService.characteristics else {
      return
    }

    guard let service = services?.first(where: { $0.uuid == cbmService.uuid }) else {
      print("found characteristics for unknown service \(cbmService.uuid)")
      return
    }

    var characteristics = [Characteristic]()
    for cbCharacteristic in cbCharacteristics {
      let characteristic = await Characteristic(characteristic: cbCharacteristic, service: service)
      characteristics.append(characteristic)
    }

    delegate?.peripheral(cbPeripheral, didDiscoverCharacteristicsFor: cbmService, error: error)

    await service.setCharacteristics(characteristics)

    discoverCharacteristicsContinuations[service.uuid]?.forEach {
      $0.resume(with: Result.success(characteristics))
    }
    discoverCharacteristicsContinuations[service.uuid] = []

  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateValueFor cbCharacteristic: CBMCharacteristic,
    error: Error?
  ) async {
    defer {
      readCharacteristicValueContinuations[cbCharacteristic.uuid] = []
    }
    delegate?.peripheral(cbPeripheral, didUpdateValueFor: cbCharacteristic, error: error)

    if let error {
      readCharacteristicValueContinuations[cbCharacteristic.uuid]?.forEach {
        $0.resume(throwing: error)
      }
      return
    }

    readCharacteristicValueContinuations[cbCharacteristic.uuid]?.forEach {
      $0.resume(with: Result.success(cbCharacteristic.value))
    }

    let service = services?.first(where: { $0.uuid == cbCharacteristic.service?.uuid })
    let characteristic = await service?.characteristics?.first(where: {
      $0.uuid == cbCharacteristic.uuid
    })
    await characteristic?.setValue(cbCharacteristic.value)
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didWriteValueFor \(characteristic) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didUpdateNotificationStateFor \(characteristic) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didDiscoverDescriptorsFor \(characteristic) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didUpdateValueFor \(descriptor) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didWriteValueFor \(descriptor) error \(String(describing: error))"
    )
  }

  func peripheralIsReady(toSendWriteWithoutResponse cbPeripheral: CBMPeripheral) {
    print("peripheralIsReadyToSendWriteWithoutResponse \(cbPeripheral)")
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    print(
      "peripheral \(cbPeripheral) didOpen \(String(describing: channel)) error \(String(describing: error))"
    )
    delegate?.peripheral(cbPeripheral, didOpen: channel, error: error)
  }
}

class PeripheralDelegate: NSObject, CBMPeripheralDelegate, @unchecked Sendable {
  let peripheral: Peripheral
  init(peripheral: Peripheral) {
    self.peripheral = peripheral
  }

  func peripheralDidUpdateName(_ cbPeripheral: CBMPeripheral) {
    Task {
      await peripheral.peripheralDidUpdateName(cbPeripheral)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didModifyServices invalidatedServices: [CBMService]
  ) {
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
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverIncludedServicesFor service: CBMService, error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral, didDiscoverIncludedServicesFor: service, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didDiscoverIncludedServicesFor: service, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didWriteValueFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral, didUpdateNotificationStateFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didUpdateNotificationStateFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didDiscoverDescriptorsFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral, didDiscoverDescriptorsFor: characteristic, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didDiscoverDescriptorsFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didUpdateValueFor descriptor: CBMDescriptor, error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: descriptor, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didUpdateValueFor: descriptor, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral, didWriteValueFor descriptor: CBMDescriptor, error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: descriptor, error: error)
      await peripheral.delegate?.peripheral(
        cbPeripheral, didWriteValueFor: descriptor, error: error)
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
    }
  }
}
