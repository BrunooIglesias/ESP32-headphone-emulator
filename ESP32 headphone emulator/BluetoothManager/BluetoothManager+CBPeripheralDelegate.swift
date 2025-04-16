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
                peripheral.discoverCharacteristics([BluetoothConstants.commandUUID,
                                                      BluetoothConstants.statusUUID,
                                                      BluetoothConstants.documentUUID],
                                                   for: service)
            } else if service.uuid == BluetoothConstants.gaiaServiceUUID {
                peripheral.discoverCharacteristics([BluetoothConstants.gaiaCommandUUID,
                                                      BluetoothConstants.gaiaResponseUUID,
                                                      BluetoothConstants.gaiaDataUUID],
                                                   for: service)
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
            case BluetoothConstants.documentUUID:
                documentCharacteristic = characteristic
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
        guard error == nil else {
            print("Error updating value for characteristic: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        if characteristic == gaiaDataCharacteristic {
            if data.count >= 4 {
                let command = data[1]
                let payloadLength = (UInt16(data[3]) << 8) | UInt16(data[2])
                
                if command == 0x47 {
                    let payload = data.subdata(in: 4..<data.count)
                    if let chunk = String(data: payload, encoding: .utf8) {
                        DispatchQueue.main.async {
                            if self.receivedDocument == nil {
                                self.receivedDocument = ""
                            }
                            self.receivedDocument? += chunk
                            print("Received document chunk: \(chunk)")
                        }
                    }
                }
            }
        } else if characteristic == gaiaResponseCharacteristic {
            handleGaiaResponse(data)
        } else if characteristic == statusCharacteristic,
                  let statusData = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
            deviceStatus = statusData
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Notification update error for \(characteristic.uuid): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Document Data Handling
    
    private func handleReceivedDocument(_ data: Data) {
        print("Document data received: \(data.count) bytes")
        if let message = String(data: data, encoding: .utf8) {
            switch message {
            case "Document transfer started":
                documentBuffer = Data()
                isDocumentTransferInProgress = true
                documentTransferProgress = 0.0
            case "Document transfer completed":
                documentData = documentBuffer
                isDocumentTransferInProgress = false
                documentTransferProgress = 1.0
                saveDocument()
            case "Chunk received":
                if let peripheral = connectedPeripheral,
                   let characteristic = documentCharacteristic {
                    peripheral.writeValue("ACK".data(using: .utf8)!,
                                            for: characteristic,
                                            type: .withResponse)
                }
            default:
                documentBuffer.append(data)
                let maxExpected: Float = 1024 * 1024
                documentTransferProgress = min(1.0, Float(documentBuffer.count) / maxExpected)
            }
        } else {
            documentBuffer.append(data)
            let maxExpected: Float = 1024 * 1024
            documentTransferProgress = min(1.0, Float(documentBuffer.count) / maxExpected)
        }
    }
    
    private func saveDocument() {
        let fileName = "received_document_\(Date().timeIntervalSince1970).txt"
        let fileURL = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask)[0].appendingPathComponent(fileName)
        do {
            try documentData.write(to: fileURL)
            print("Document saved at \(fileURL.path)")
        } catch {
            print("Error saving document: \(error.localizedDescription)")
        }
    }
}
