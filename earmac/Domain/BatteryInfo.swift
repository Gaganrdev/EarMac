import Foundation

struct BatteryLevel: Sendable, Equatable {
    let level: Int
    let isCharging: Bool
    let isConnected: Bool

    static let disconnected = BatteryLevel(level: 0, isCharging: false, isConnected: false)
}

struct BatteryInfo: Sendable, Equatable {
    let caseBattery: BatteryLevel
    let leftBud: BatteryLevel
    let rightBud: BatteryLevel
}
