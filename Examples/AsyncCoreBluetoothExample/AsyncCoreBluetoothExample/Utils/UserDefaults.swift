//
//  UserDefaults.swift
//  AsyncCoreBluetoothExample
//
//  Created by Sam Meech-Ward on 2025-03-08.
//

import Foundation
import AsyncObservableUserDefaults

final class UserDefaults {
  static let connectedDeviceId: AsyncObservableUserDefaults<String?> = .init(key: "connectedDeviceId", initialValue: nil)
}
