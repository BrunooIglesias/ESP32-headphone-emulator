//
//  BluetoothDevice.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import Foundation
import CoreBluetooth

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
