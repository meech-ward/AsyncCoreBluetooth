# Getting Started with Async Core Bluetooth and Accessory Setup Kit


@Metadata {
    @PageImage(purpose: card, source: "icon", alt: "Async Core Bluetooth")
}

## Overview

Async Core Bluetooth

### Initializing The Central Manager

Setup the central manager and check the current ble state:

```swift
import AccessorySetupKit

// Create a session
var session = ASAccessorySession()

// Activate session with event handler
session.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent(event:))

// Handle event
func handleSessionEvent(event: ASAccessoryEvent) {  
    switch event.eventType {
    case .activated:
        print("Session is activated and ready to use")
        print(session.accessories)
    default:
        print("Received event type \(event.eventType)")
    }
}
```


```swift 
// Create descriptor for pink dice
let pinkDescriptor = ASDiscoveryDescriptor()
pinkDescriptor.bluetoothServiceUUID = pinkUUID
// Create descriptor for blue dice
let blueDescriptor = ASDiscoveryDescriptor()
blueDescriptor.bluetoothServiceUUID = blueUUID

// Create picker display items
let pinkDisplayItem = ASPickerDisplayItem(
    name: "Pink Dice",
    productImage: UIImage(named: "pink")!,
    descriptor: pinkDescriptor
)
let blueDisplayItem = ASPickerDisplayItem(
    name: "Blue Dice",
    productImage: UIImage(named: "blue")!,
    descriptor: blueDescriptor
)
```