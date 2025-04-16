//
//  BluetoothManager.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var documentCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    private let commandUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    private let statusUUID = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")
    private let documentUUID = CBUUID(string: "0000FFE3-0000-1000-8000-00805F9B34FB")
    
    // GAIA Protocol Constants
    private let gaiaServiceUUID = CBUUID(string: "00001100-D102-11E1-9B23-00025B00A5A5")
    private let gaiaCommandUUID = CBUUID(string: "00001101-D102-11E1-9B23-00025B00A5A5")
    private let gaiaResponseUUID = CBUUID(string: "00001102-D102-11E1-9B23-00025B00A5A5")
    private let gaiaDataUUID = CBUUID(string: "00001103-D102-11E1-9B23-00025B00A5A5")
    
    private var gaiaCommandCharacteristic: CBCharacteristic?
    private var gaiaResponseCharacteristic: CBCharacteristic?
    private var gaiaDataCharacteristic: CBCharacteristic?
    
    private let maxGaiaPacketSize = 20
    private let maxGaiaPayloadSize = 12
    private var imageTransferInProgress = false
    private var currentImageData = Data()
    private var imageChunks: [Data] = []
    private var currentChunkIndex = 0
    
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning = false
    @Published var connectionStatus = "Disconnected"
    @Published var deviceStatus: DeviceStatus?
    @Published var receivedMessage = ""
    @Published var isBluetoothAvailable = false
    @Published var documentData = Data()
    @Published var isDocumentTransferInProgress = false
    @Published var documentTransferProgress: Float = 0.0
    @Published var isImageTransferInProgress = false
    @Published var imageTransferProgress: Float = 0.0
    
    private var documentBuffer = Data()
    
    private let commandQueue = DispatchQueue(label: "com.esp32headphone.commandqueue")
    private var currentCommand: Data?
    private var isWaitingForResponse = false
    private let maxChunkSize = 512
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on. Current state: \(centralManager.state.rawValue)")
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        print("Starting scan for devices...")
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                self.centralManager.stopScan()
                self.centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            }
        }
    }
    
    func stopScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = false
        centralManager.stopScan()
    }
    
    func connect(to device: BluetoothDevice) {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on. Current state: \(centralManager.state.rawValue)")
            return
        }
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }),
           let peripheral = discoveredDevices[index].peripheral {
            print("Found peripheral, connecting...")
            stopScanning()
            centralManager.connect(peripheral, options: nil)
        } else {
            print("Error: Could not find peripheral for device")
            if let peripheral = device.peripheral {
                print("Found peripheral in device, connecting...")
                stopScanning()
                centralManager.connect(peripheral, options: nil)
            } else {
                print("Error: Peripheral is nil")
            }
        }
    }
    
    func disconnect() {
        guard centralManager.state == .poweredOn else { return }
        if let peripheral = connectedPeripheral {
            print("Disconnecting from peripheral: \(peripheral.name ?? "Unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func sendCommand(_ command: String) {
        guard centralManager.state == .poweredOn,
              let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic else { return }
        
        let data = command.data(using: .utf8)!
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func requestStatus() {
        guard centralManager.state == .poweredOn,
              let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic else { return }
        
        let data = "GET_STATUS".data(using: .utf8)!
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func startDocumentTransfer() {
        guard let peripheral = connectedPeripheral,
              let characteristic = documentCharacteristic else { 
            print("Cannot start document transfer: peripheral or characteristic not available")
            return 
        }
        print("Starting document transfer...")
        peripheral.writeValue("START_DOCUMENT".data(using: .utf8)!, for: characteristic, type: .withResponse)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendDocumentData()
        }
    }
    
    private func sendDocumentData() {
        guard let peripheral = connectedPeripheral,
              let characteristic = documentCharacteristic else { return }
        
        let documentText = """
        This is a sample document that will be transferred over Bluetooth.
        It contains multiple lines of text to demonstrate the transfer functionality.
        The document will be sent in chunks to ensure reliable transmission.
        Each chunk will be acknowledged by the ESP32 before sending the next one.
        """
        
        let chunkSize = 20
        let chunks = stride(from: 0, to: documentText.count, by: chunkSize).map {
            let start = documentText.index(documentText.startIndex, offsetBy: $0)
            let end = documentText.index(start, offsetBy: min(chunkSize, documentText.count - $0), limitedBy: documentText.endIndex) ?? documentText.endIndex
            return String(documentText[start..<end])
        }
        
        for chunk in chunks {
            print("Sending chunk: \(chunk)")
            peripheral.writeValue(chunk.data(using: .utf8)!, for: characteristic, type: .withResponse)
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        endDocumentTransfer()
    }

    func endDocumentTransfer() {
        guard let peripheral = connectedPeripheral,
              let characteristic = documentCharacteristic else { 
            print("Cannot end document transfer: peripheral or characteristic not available")
            return 
        }
        print("Ending document transfer...")
        peripheral.writeValue("END_DOCUMENT".data(using: .utf8)!, for: characteristic, type: .withResponse)
    }

    func sendImage(_ imageData: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = gaiaCommandCharacteristic else {
            print("Cannot send image: peripheral or characteristic not available")
            return
        }
        
        print("Starting image transfer with size: \(imageData.count) bytes")
        
        imageChunks = prepareImageChunks(imageData)
        currentChunkIndex = 0
        imageTransferInProgress = true
        
        var sizeBytes = UInt32(imageData.count).littleEndian
        let sizeData = Data(bytes: &sizeBytes, count: MemoryLayout<UInt32>.size)
        
        let startCommand = createGaiaCommand(command: 0x46, payload: sizeData)
        print("Sending start command (0x46) with size: \(sizeData.count) bytes")
        
        commandQueue.async { [weak self] in
            self?.sendCommand(startCommand, characteristic: characteristic)
        }
    }
    
    private func sendCommand(_ data: Data, characteristic: CBCharacteristic) {
        guard !isWaitingForResponse else {
            print("Waiting for previous command response")
            return
        }
        
        isWaitingForResponse = true
        currentCommand = data
        
        if let peripheral = connectedPeripheral {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    private func sendNextImageChunk() {
        guard imageTransferInProgress,
              currentChunkIndex < imageChunks.count,
              let peripheral = connectedPeripheral,
              let characteristic = gaiaDataCharacteristic else {
            print("Cannot send next chunk: transfer not in progress or invalid state")
            return
        }
        
        let chunk = imageChunks[currentChunkIndex]
        let chunkCommand = createGaiaCommand(command: 0x47, payload: chunk)
        print("Sending chunk \(currentChunkIndex + 1)/\(imageChunks.count) of size: \(chunk.count) bytes")
        
        commandQueue.async { [weak self] in
            self?.sendCommand(chunkCommand, characteristic: characteristic)
        }
    }
    
    private func handleGaiaResponse(_ data: Data) {
        guard data.count >= 4 else {
            print("Invalid GAIA response: too short")
            return
        }
        
        let command = data[1]
        let status = data[3]
        
        print("Received GAIA response: command=0x\(String(format: "%02X", command)), status=0x\(String(format: "%02X", status))")
        
        isWaitingForResponse = false
        
        switch command {
        case 0x46:
            if status == 0x00 {
                print("Image transfer start acknowledged successfully")
                imageTransferProgress = 0.0
                sendNextImageChunk()
            } else {
                print("Failed to start image transfer. Status: \(status)")
                imageTransferInProgress = false
                imageChunks.removeAll()
                currentChunkIndex = 0
            }
            
        case 0x47:
            if status == 0x00 {
                currentChunkIndex += 1
                imageTransferProgress = Float(currentChunkIndex) / Float(imageChunks.count)
                print("Chunk \(currentChunkIndex)/\(imageChunks.count) acknowledged")
                
                if currentChunkIndex < imageChunks.count {
                    sendNextImageChunk()
                } else {
                    imageTransferInProgress = false
                    imageTransferProgress = 1.0
                    imageChunks.removeAll()
                    currentChunkIndex = 0
                    print("Image transfer completed successfully")
                }
            } else {
                print("Failed to send image chunk. Status: \(status)")
                imageTransferInProgress = false
                imageChunks.removeAll()
                currentChunkIndex = 0
            }
            
        default:
            print("Unknown GAIA command response: 0x\(String(format: "%02X", command))")
            break
        }
    }
    
    private func prepareImageChunks(_ data: Data) -> [Data] {
        var chunks: [Data] = []
        let chunkSize = maxGaiaPayloadSize
        
        var offset = 0
        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data[offset..<(offset + length)]
            chunks.append(Data(chunk))
            offset += length
        }
        
        print("Prepared \(chunks.count) chunks of size \(chunkSize) bytes each")
        return chunks
    }
    
    private func createGaiaCommand(command: UInt8, payload: Data) -> Data {
        var packet = Data()
        packet.append(0x10)
        packet.append(command)
        let length = UInt16(payload.count).littleEndian
        withUnsafeBytes(of: length) { bytes in
            packet.append(contentsOf: bytes)
        }
        packet.append(payload)
        return packet
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state updated: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            isBluetoothAvailable = true
            connectionStatus = "Ready to scan"
            print("Bluetooth is powered on, starting scan...")
            if connectedPeripheral == nil {
                startScanning()
            }
        case .poweredOff:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is powered off"
            isScanning = false
            print("Please turn on Bluetooth to use this app")
        case .resetting:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is resetting"
            isScanning = false
            print("Bluetooth is resetting, please wait...")
        case .unauthorized:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is unauthorized"
            isScanning = false
            print("Bluetooth access is unauthorized. Please check your settings.")
        case .unknown:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth state is unknown"
            isScanning = false
            print("Bluetooth state is unknown. Please try again.")
        case .unsupported:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is not supported"
            isScanning = false
            print("Bluetooth is not supported on this device")
        @unknown default:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth state is unknown"
            isScanning = false
            print("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        peripheral.delegate = self
        
        if let existingIndex = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[existingIndex].rssi = RSSI.intValue
            discoveredDevices[existingIndex].peripheral = peripheral
        } else {
            let device = BluetoothDevice(
                id: peripheral.identifier,
                name: peripheral.name ?? "Unknown Device",
                rssi: RSSI.intValue,
                isConnected: false,
                peripheral: peripheral
            )
            discoveredDevices.append(device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Successfully connected to peripheral: \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionStatus = "Connected"
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = true
        }
        
        peripheral.discoverServices([serviceUUID, gaiaServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        connectionStatus = "Connection failed"
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        commandCharacteristic = nil
        statusCharacteristic = nil
        documentCharacteristic = nil
        connectionStatus = "Disconnected"
        deviceStatus = nil
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = false
        }
        
        if central.state == .poweredOn {
            startScanning()
        }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([commandUUID, statusUUID, documentUUID], for: service)
            } else if service.uuid == gaiaServiceUUID {
                peripheral.discoverCharacteristics([gaiaCommandUUID, gaiaResponseUUID, gaiaDataUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == commandUUID {
                commandCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == statusUUID {
                statusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == documentUUID {
                documentCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == gaiaCommandUUID {
                gaiaCommandCharacteristic = characteristic
            } else if characteristic.uuid == gaiaResponseUUID {
                gaiaResponseCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == gaiaDataUUID {
                gaiaDataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error receiving notification: \(error!.localizedDescription)")
            return
        }
        
        if let data = characteristic.value {
            if characteristic.uuid == gaiaResponseUUID {
                handleGaiaResponse(data)
            } else if characteristic.uuid == documentUUID {
                handleDocumentData(data)
            } else if let message = String(data: data, encoding: .utf8) {
                receivedMessage = message
                
                if characteristic.uuid == statusUUID {
                    if let statusData = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
                        deviceStatus = statusData
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error setting notification state: \(error!.localizedDescription)")
            return
        }
    }
    
    private func handleDocumentData(_ data: Data) {
        print("Received data of size: \(data.count) bytes")
        
        if let message = String(data: data, encoding: .utf8) {
            print("Received message: \(message)")
            
            if message == "Document transfer started" {
                print("Document transfer started")
                documentBuffer = Data()
                isDocumentTransferInProgress = true
                documentTransferProgress = 0.0
            } else if message == "Document transfer completed" {
                print("Document transfer completed")
                documentData = documentBuffer
                isDocumentTransferInProgress = false
                documentTransferProgress = 1.0
                saveDocument()
            } else if message == "Chunk received" {
                print("Chunk acknowledged")
                
                if let peripheral = connectedPeripheral,
                   let characteristic = documentCharacteristic {
                    peripheral.writeValue("ACK".data(using: .utf8)!, for: characteristic, type: .withResponse)
                }
            } else {
                print("Received document chunk of size: \(data.count) bytes")
                documentBuffer.append(data)
                let maxExpectedSize: Float = 1024 * 1024 // 1MB
                let newProgress = min(1.0, Float(documentBuffer.count) / maxExpectedSize)
                if newProgress != documentTransferProgress {
                    documentTransferProgress = newProgress
                    print("Document transfer progress: \(Int(documentTransferProgress * 100))% (Buffer size: \(documentBuffer.count) bytes)")
                }
            }
        } else {
            print("Received binary chunk of size: \(data.count) bytes")
            documentBuffer.append(data)

            let maxExpectedSize: Float = 1024 * 1024
            let newProgress = min(1.0, Float(documentBuffer.count) / maxExpectedSize)
            if newProgress != documentTransferProgress {
                documentTransferProgress = newProgress
                print("Document transfer progress: \(Int(documentTransferProgress * 100))% (Buffer size: \(documentBuffer.count) bytes)")
            }
        }
    }
    
    private func saveDocument() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "received_document_\(Date().timeIntervalSince1970).txt"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try documentData.write(to: fileURL)
            print("Document saved successfully at: \(fileURL.path)")
        } catch {
            print("Error saving document: \(error.localizedDescription)")
        }
    }
}
