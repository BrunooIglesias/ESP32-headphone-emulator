//
//  BluetoothManager+CBPeripheralDelegate.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/16/25.
//

import CoreBluetooth

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            print("Error discovering services: \(error?.localizedDescription ?? "unknown")")
            return
        }
        for service in services {
            if service.uuid == BluetoothConstants.serviceUUID {
                peripheral.discoverCharacteristics([
                    BluetoothConstants.commandUUID,
                    BluetoothConstants.statusUUID
                ], for: service)

            } else if service.uuid == BluetoothConstants.gaiaServiceUUID {
                peripheral.discoverCharacteristics([
                    BluetoothConstants.gaiaCommandUUID,
                    BluetoothConstants.gaiaResponseUUID,
                    BluetoothConstants.gaiaDataUUID
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case BluetoothConstants.commandUUID:
                commandCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case BluetoothConstants.statusUUID:
                statusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case BluetoothConstants.gaiaCommandUUID:
                gaiaCommandCharacteristic = characteristic
            case BluetoothConstants.gaiaResponseUUID:
                gaiaResponseCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case BluetoothConstants.gaiaDataUUID:
                gaiaDataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else {
            if let e = error { print("Error updating value for characteristic: \(e.localizedDescription)") }
            return
        }

        switch characteristic {
        case gaiaDataCharacteristic:
            if data.count >= 4 {
                let command = data[1]
                let payloadLength = Int(UInt16(data[3]) << 8 | UInt16(data[2]))
                if data.count >= 4 + payloadLength && command == 0x47 {
                    let payload = data.subdata(in: 4 ..< 4 + payloadLength)
                    if let chunk = String(data: payload, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.receivedDocument = (self.receivedDocument ?? "") + chunk
                        }
                        print("Received GAIA chunk: \(chunk)")
                    }
                }
            }
        case gaiaResponseCharacteristic:
            handleGaiaResponse(data)
        case statusCharacteristic:
            if let status = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
                deviceStatus = status
            }
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Notification update error for \(characteristic.uuid): \(error.localizedDescription)")
        }
    }
}
