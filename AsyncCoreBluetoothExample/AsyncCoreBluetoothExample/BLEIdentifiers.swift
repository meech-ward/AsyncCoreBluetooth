enum BLEIdentifiers {
  static let name = "NimBLE_GATT"
  /// Service UUIDs
  enum Service {
    /// Heart Rate Service (0x180D)
    static let heartRate = CBUUID(string: "180D")

    /// Automation IO Service (0x1815)
    static let automationIO = CBUUID(string: "1815")
  }

  static let services: [CBUUID] = [
    Service.heartRate,
    Service.automationIO
  ]

  /// Characteristic UUIDs
  enum Characteristic {
    /// Heart Rate Measurement Characteristic (0x2A37)
    static let heartRateMeasurement = CBUUID(string: "2A37")

    /// LED Control Characteristic
    static let ledControl = CBUUID(string: "00001525-1212-EFDE-1523-785FEABCD123")
  }
}