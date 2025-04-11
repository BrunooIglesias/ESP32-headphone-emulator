import Foundation

struct DeviceStatus: Codable {
    let playing: Bool
    let volume: Int
    let battery: Int
    let signal: Int
}
