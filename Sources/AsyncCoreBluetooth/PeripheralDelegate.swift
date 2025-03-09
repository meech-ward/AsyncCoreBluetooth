@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import DequeModule
import Foundation

// CBMPeripheralDelegate
extension Peripheral {
  // MARK: - Peripheral Events not yet implemented

  // but can still be accessed via the delegate

  func peripheralDidUpdateName(_ cbPeripheral: CBMPeripheral) {
    print("peripheralDidUpdateName \(cbPeripheral)")
    delegate?.peripheralDidUpdateName(cbPeripheral)
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didModifyServices invalidatedServices: [CBMService]
  ) {
    print("peripheral \(cbPeripheral) didModifyServices \(invalidatedServices)")
    delegate?.peripheral(cbPeripheral, didModifyServices: invalidatedServices)
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    print("peripheral \(cbPeripheral) didReadRSSI \(RSSI) error \(String(describing: error))")
    delegate?.peripheral(cbPeripheral, didReadRSSI: RSSI, error: error)
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didDiscoverIncludedServicesFor service: CBMService,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didDiscoverIncludedServicesFor \(service) error \(String(describing: error))"
    )
    delegate?.peripheral(cbPeripheral, didDiscoverIncludedServicesFor: service, error: error)
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didDiscoverDescriptorsFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didDiscoverDescriptorsFor \(characteristic) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didUpdateValueFor descriptor: CBMDescriptor,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didUpdateValueFor \(descriptor) error \(String(describing: error))"
    )
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didWriteValueFor descriptor: CBMDescriptor,
    error: Error?
  ) {
    print(
      "peripheral \(cbPeripheral) didWriteValueFor \(descriptor) error \(String(describing: error))"
    )
    delegate?.peripheral(cbPeripheral, didWriteValueFor: descriptor, error: error)
  }

  func peripheralIsReady(toSendWriteWithoutResponse cbPeripheral: CBMPeripheral) {
    delegate?.peripheralIsReady(toSendWriteWithoutResponse: cbPeripheral)
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    print(
      "peripheral \(cbPeripheral) didOpen \(String(describing: channel)) error \(String(describing: error))"
    )
    delegate?.peripheral(cbPeripheral, didOpen: channel, error: error)
  }

  // MARK: - Peripheral Events

  // TODO: this needs to be tested more
  // like if you call mulltiple discover services
  // and then discover characteristics
  // will the characteristics be added to the correct service
  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverServices error: Error?) async {
    print("discovered service \(cbPeripheral.services) \(discoverServicesContinuations.count) \(self.identifier) \(ObjectIdentifier(self))")
    delegate?.peripheral(cbPeripheral, didDiscoverServices: error)
    let continuation = discoverServicesContinuations.popFirst()
    if let error {
      continuation?.resume(throwing: error)
      return
    }
    guard let cbServices = cbPeripheral.services else {
      continuation?.resume(throwing: ServiceError.unableToFindServices)
      return
    }
    var services = self.services ?? [Service]()
    var servicesMap: [CBUUID: Service] = [:]
    for cbService in cbServices {
      // this is new needs to be tested
      if let service = self.services?.first(where: { $0.uuid == cbService.uuid })  {
        servicesMap[cbService.uuid] = service
        continue
      }
      let service = await Service(service: cbService, peripheral: self)
      services.append(service)
      // only new ones to th request, the requested services
      servicesMap[cbService.uuid] = service
    }

    self.services = services
    continuation?.resume(with: Result.success(servicesMap))
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverCharacteristicsFor cbmService: CBMService, error: Error?) async {
    delegate?.peripheral(cbPeripheral, didDiscoverCharacteristicsFor: cbmService, error: error)
    let continuation = discoverCharacteristicsContinuations[cbmService.uuid]?.popFirst()
    if let error {
      continuation?.resume(throwing: error)
      return
    }

    guard let cbCharacteristics = cbmService.characteristics else {
      continuation?.resume(throwing: CharacteristicError.unableToFindCharacteristics)
      return
    }

    guard let service = services?.first(where: { $0.uuid == cbmService.uuid }) else {
      print("found characteristics for unknown service \(cbmService.uuid)")
      continuation?.resume(throwing: CharacteristicError.unableToFindCharacteristicService)
      return
    }

    var characteristics = [Characteristic]()
    var characteristicsMap: [CBUUID: Characteristic] = [:]
    for cbCharacteristic in cbCharacteristics {
      let characteristic = await Characteristic(characteristic: cbCharacteristic, service: service)
      characteristics.append(characteristic)
      characteristicsMap[cbCharacteristic.uuid] = characteristic
    }

    await service.setCharacteristics(characteristics)

    continuation?.resume(with: Result.success(characteristicsMap))
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didUpdateValueFor cbCharacteristic: CBMCharacteristic,
    error cbError: Error?
  ) async {
    delegate?.peripheral(cbPeripheral, didUpdateValueFor: cbCharacteristic, error: cbError)

    let continuation = readCharacteristicValueContinuations[cbCharacteristic.uuid]?.popFirst()
    let service = services?.first(where: { $0.uuid == cbCharacteristic.service?.uuid })
    let characteristic = await service?.characteristics?.first(where: {
      $0.uuid == cbCharacteristic.uuid
    })

    let result: Result<Data, Error> =
      if let cbError {
        Result.failure(cbError)
      }
      else if let value = cbCharacteristic.value {
        Result.success(value)
      }
      else {
        Result.failure(AsyncCoreBluetoothError.unexpectedNilData)
      }
    await characteristic?.update(result: result)

    continuation?.resume(with: result)
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
    delegate?.peripheral(cbPeripheral, didWriteValueFor: characteristic, error: error)

    let continuation = writeCharacteristicWithResponseContinuations.popFirst()
    if let error {
      continuation?.resume(throwing: error)
    }
    else {
      continuation?.resume()
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didUpdateNotificationStateFor cbCharacteristic: CBMCharacteristic, error: Error?) async {
    delegate?.peripheral(cbPeripheral, didUpdateValueFor: cbCharacteristic, error: error)
    let continuation = notifyCharacteristicValueContinuations[cbCharacteristic.uuid]?.popFirst()
    guard
      let service = services?.first(where: { $0.uuid == cbCharacteristic.service?.uuid }),
      let characteristic = await service.characteristics?.first(where: {
        $0.uuid == cbCharacteristic.uuid
      })
    else {
      print("unable to find characteristic \(cbCharacteristic.uuid) for service \(cbCharacteristic.service?.uuid) \(cbPeripheral.services))")
      continuation?.resume(throwing: CharacteristicError.unableToFindCharacteristicService)
      return
    }

    // change the is notifying value on characteristic
    await characteristic.update(isNotifying: cbCharacteristic.isNotifying)
    // make sure to add a way to listen for new notifivation values

    if let error {
      continuation?.resume(throwing: error)
      return
    }
    continuation?.resume(with: Result.success(cbCharacteristic.isNotifying))
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
    _ cbPeripheral: CBMPeripheral,
    didModifyServices invalidatedServices: [CBMService]
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didModifyServices: invalidatedServices)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didReadRSSI: RSSI, error: error)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didDiscoverServices error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didDiscoverServices: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didDiscoverIncludedServicesFor service: CBMService,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral,
        didDiscoverIncludedServicesFor: service,
        error: error
      )
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didDiscoverCharacteristicsFor service: CBMService,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral,
        didDiscoverCharacteristicsFor: service,
        error: error
      )
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didUpdateValueFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didWriteValueFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: characteristic, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didUpdateNotificationStateFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral,
        didUpdateNotificationStateFor: characteristic,
        error: error
      )
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didDiscoverDescriptorsFor characteristic: CBMCharacteristic,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(
        cbPeripheral,
        didDiscoverDescriptorsFor: characteristic,
        error: error
      )
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didUpdateValueFor descriptor: CBMDescriptor,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didUpdateValueFor: descriptor, error: error)
    }
  }

  func peripheral(
    _ cbPeripheral: CBMPeripheral,
    didWriteValueFor descriptor: CBMDescriptor,
    error: Error?
  ) {
    Task {
      await peripheral.peripheral(cbPeripheral, didWriteValueFor: descriptor, error: error)
    }
  }

  func peripheralIsReadyToSendWriteWithoutResponse(_ cbPeripheral: CBMPeripheral) {
    Task {
      await peripheral.peripheralIsReady(toSendWriteWithoutResponse: cbPeripheral)
    }
  }

  func peripheral(_ cbPeripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
    Task {
      await peripheral.peripheral(cbPeripheral, didOpen: channel, error: error)
    }
  }
}
