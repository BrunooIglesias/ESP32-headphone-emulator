import Foundation
import CoreBluetooth

struct DeviceStatus: Codable {
    let playing: Bool
    let volume: Int
    let battery: Int
    let signal: Int
}

class BluetoothDevice: Identifiable {
    let id: UUID
    let name: String
    var rssi: Int
    var isConnected: Bool
    var peripheral: CBPeripheral?
    
    init(id: UUID, name: String, rssi: Int, isConnected: Bool, peripheral: CBPeripheral?) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.isConnected = isConnected
        self.peripheral = peripheral
    }
} 