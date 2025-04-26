//
//  AccessoryManager.swift
//  Eye Camera UIKit
//
//  Created by Sam Meech-Ward on 2024-12-31.
//

@preconcurrency import AccessorySetupKit
import Foundation
import MightFail
import AsyncObservable

// https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories

@MainActor
final class AccessoryManager {
  enum AccessoryError: LocalizedError {
    case noAccessory
    case unknownError
    case sessionInvalidated

    // Localized description that will be shown to users
    var errorDescription: String? {
      switch self {
      case .noAccessory:
        return NSLocalizedString(
          "No accessory found",
          comment: "Error shown when no accessory is found"
        )
      case .unknownError:
        return NSLocalizedString(
          "Unknown error",
          comment: "Error shown when an unknown error occurs"
        )
      case .sessionInvalidated:
        return NSLocalizedString("Session invalidated", comment: "Error shown when the session is invalidated")
      }
    }
  }

  // Create a session
  @MainActor
  private var session = ASAccessorySession()

  @MainActor
  let eventType: AsyncObservable<ASAccessoryEventType> = .init(.unknown)

  @MainActor
  let accessory: AsyncObservable<ASAccessory?> = .init(nil)
  @MainActor
  init() {
    // Activate session with event handler
  }

  private var activateSessionContinuation: CheckedContinuation<ASAccessory?, Error>?
  var activated = false
  func activateSessionIfNotActivated() async throws -> ASAccessory? {
    if activated {
      return accessory.current
    }
    return try await withCheckedThrowingContinuation { activateSessionContinuation in
      self.activateSessionContinuation = activateSessionContinuation
      session.activate(on: .main, eventHandler: handleSessionEvent(event:))
    }
  }

  @MainActor
  private var showPickerContinuation: CheckedContinuation<ASAccessory?, Error>?
  @MainActor
  func showPicker() async throws -> ASAccessory? {
    return try await withCheckedThrowingContinuation { @MainActor continuation in
      self.showPickerContinuation = continuation

      let descriptor = ASDiscoveryDescriptor()
      descriptor.bluetoothServiceUUID = BLEIdentifiers.Service.heartRate
      // https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/confirmauthorization
//      descriptor.supportedOptions = [ /*.bluetoothPairingLE*/]

      let displayItem = ASPickerDisplayItem(
        name: "GATT Heart Rate Monitor",
        productImage: UIImage(systemName: "heart.fill")!,
        descriptor: descriptor
      )
      //          displayItem.setupOptions = [.confirmAuthorization, .finishInApp]
//      displayItem.setupOptions = []

      session.showPicker(for: [displayItem]) { error in
        if let error {
          self.showPickerContinuation?.resume(throwing: error)
          self.showPickerContinuation = nil
        }
      }
    }
  }

  // Handle event
  private func handleSessionEvent(event: ASAccessoryEvent) {
    eventType.update(event.eventType)
    switch event.eventType {
    case .unknown:
      print("Unknown event occurred (eventType: 0)")

    case .activated:
      print("Session activated (eventType: 10)")
      // set any stored accessories
      accessory.update(session.accessories.first)
      activated = true
      activateSessionContinuation?.resume(returning: accessory.current)
      activateSessionContinuation = nil

    case .invalidated:
      print("Session invalidated (eventType: 11)")
      activateSessionContinuation?.resume(throwing: AccessoryError.sessionInvalidated)
      activateSessionContinuation = nil

    case .migrationComplete:
      print("Accessory migration completed (eventType: 20)")

    case .accessoryAdded:
      print("Accessory added to session (eventType: 30)")

    // I think this needs to be done in order to actually bond
    // but i haven't needed it so far
    // https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/confirmauthorization
    //      self.accessory = session.accessories.first
    //      guard let accessory else {
    //        print("error property changed but not accessory to do shit with")
    //        return
    //      }
    //      self.accessory = accessory
    //
    ////      guard let identifier = accessory.bluetoothIdentifier else {
    ////        print("error got nil identifier")
    ////        return
    ////      }
    //      PiCameraBLEManager.shared.scanAndConnect()

    case .accessoryRemoved:
      print("Accessory removed from session (eventType: 31)")
      accessory.update(nil)

    case .accessoryChanged:
      print("Accessory properties changed (eventType: 32)")

    case .pickerDidPresent:
      print("Picker view presented (eventType: 40)")

    case .pickerDidDismiss:
      print("Picker view dismissed (eventType: 50)")
      accessory.update(session.accessories.first)
      showPickerContinuation?.resume(returning: accessory.current)
      showPickerContinuation = nil

    case .pickerSetupBridging:
      print("Picker started bridging with accessory (eventType: 60)")

    case .pickerSetupFailed:
      print("Picker setup failed (eventType: 70)")
      showPickerContinuation?.resume(throwing: AccessoryError.unknownError)
      showPickerContinuation = nil

    case .pickerSetupPairing:
      print("Picker started Bluetooth pairing (eventType: 80)")

    case .pickerSetupRename:
      print("Picker started accessory rename (eventType: 90)")

    default:
      print("Received event type \(event.eventType)")
    }
  }
}
