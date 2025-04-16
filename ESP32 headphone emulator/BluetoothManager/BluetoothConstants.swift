//
//  BluetoothConstants.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/16/25.
//

import CoreBluetooth

enum BluetoothConstants {
    static let serviceUUID    = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let commandUUID    = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    static let statusUUID     = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")
    static let documentUUID   = CBUUID(string: "0000FFE3-0000-1000-8000-00805F9B34FB")
    
    static let gaiaServiceUUID   = CBUUID(string: "00001100-D102-11E1-9B23-00025B00A5A5")
    static let gaiaCommandUUID   = CBUUID(string: "00001101-D102-11E1-9B23-00025B00A5A5")
    static let gaiaResponseUUID  = CBUUID(string: "00001102-D102-11E1-9B23-00025B00A5A5")
    static let gaiaDataUUID      = CBUUID(string: "00001103-D102-11E1-9B23-00025B00A5A5")
}
