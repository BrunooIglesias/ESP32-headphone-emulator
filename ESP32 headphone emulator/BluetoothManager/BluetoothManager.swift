//
//  BluetoothManager.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
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
    @Published var isFileTransferInProgress = false
    @Published var fileTransferProgress: Float = 0.0
    @Published var currentFileType: FileType = .unknown
    @Published var receivedDocument: String? = nil
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    internal var connectedPeripheral: CBPeripheral?
    
    var commandCharacteristic: CBCharacteristic?
    var statusCharacteristic: CBCharacteristic?
    var documentCharacteristic: CBCharacteristic?
    
    var gaiaCommandCharacteristic: CBCharacteristic?
    var gaiaResponseCharacteristic: CBCharacteristic?
    var gaiaDataCharacteristic: CBCharacteristic?
    
    private let commandQueue = DispatchQueue(label: "com.esp32headphone.commandqueue")
    private var isWaitingForResponse = false
    private let maxGaiaPayloadSize = 12
    private var imageChunks: [Data] = []
    private var currentChunkIndex = 0
    internal var documentBuffer = Data()
    private var fileChunks: [Data] = []
    private var currentFileData: Data?
    private var currentFileName: String?
    
    // MARK: - File Type
    enum FileType {
        case image, document, unknown
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self,
                                            queue: DispatchQueue.main,
                                            options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not powered on. State: \(centralManager.state.rawValue)")
            return
        }
        discoveredDevices.removeAll()
        isScanning = true
        print("Starting scan for peripherals...")
        centralManager.scanForPeripherals(withServices: nil,
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.centralManager.stopScan()
            self.centralManager.scanForPeripherals(withServices: [BluetoothConstants.serviceUUID],
                                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }
    
    func stopScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = false
        centralManager.stopScan()
    }
    
    func connect(to device: BluetoothDevice) {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not powered on. State: \(centralManager.state.rawValue)")
            return
        }
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }),
           let peripheral = discoveredDevices[index].peripheral {
            print("Connecting to peripheral: \(peripheral.name ?? "Unknown")")
            stopScanning()
            centralManager.connect(peripheral, options: nil)
        } else if let peripheral = device.peripheral {
            print("Connecting via device peripheral...")
            stopScanning()
            centralManager.connect(peripheral, options: nil)
        } else {
            print("Error: Peripheral not found.")
        }
    }
    
    func disconnect() {
        guard centralManager.state == .poweredOn,
              let peripheral = connectedPeripheral else { return }
        print("Disconnecting from \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral,
              let commandCharacteristic = commandCharacteristic else { return }
        
        let data = command.data(using: .utf8)!
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
    }
    
    func requestStatus() {
        sendCommand("GET_STATUS")
    }
    
    func requestDocument() {
        guard let peripheral = connectedPeripheral,
              let characteristic = gaiaCommandCharacteristic else { return }
        
        let command = createGaiaCommand(command: 0x46, payload: Data([0x02]))
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(command, characteristic: characteristic)
        }
    }
    
    // MARK: - Document Transfer Methods
    func startDocumentTransfer() {
        guard let peripheral = connectedPeripheral,
              let characteristic = documentCharacteristic else {
            print("Document transfer cannot be started")
            return
        }
        print("Starting document transfer...")
        peripheral.writeValue("START_DOCUMENT".data(using: .utf8)!,
                                for: characteristic,
                                type: .withResponse)
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
        let chunks = stride(from: 0, to: documentText.count, by: chunkSize).map { index -> String in
            let start = documentText.index(documentText.startIndex, offsetBy: index)
            let end = documentText.index(start,
                                         offsetBy: min(chunkSize, documentText.count - index),
                                         limitedBy: documentText.endIndex) ?? documentText.endIndex
            return String(documentText[start..<end])
        }
        
        for chunk in chunks {
            print("Sending document chunk: \(chunk)")
            peripheral.writeValue(chunk.data(using: .utf8)!,
                                  for: characteristic,
                                  type: .withResponse)
            Thread.sleep(forTimeInterval: 0.1)
        }
        endDocumentTransfer()
    }
    
    func endDocumentTransfer() {
        guard let peripheral = connectedPeripheral,
              let characteristic = documentCharacteristic else {
            print("Document transfer cannot be ended")
            return
        }
        print("Ending document transfer...")
        peripheral.writeValue("END_DOCUMENT".data(using: .utf8)!,
                                for: characteristic,
                                type: .withResponse)
    }
    
    // MARK: - Image and File Transfer Methods
    func sendImage(_ imageData: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = gaiaCommandCharacteristic else {
            print("Image transfer cannot be started")
            return
        }
        print("Starting image transfer with \(imageData.count) bytes")
        imageChunks = prepareChunks(from: imageData, chunkSize: maxGaiaPayloadSize)
        currentChunkIndex = 0
        
        var sizeBytes = UInt32(imageData.count).littleEndian
        let sizeData = Data(bytes: &sizeBytes, count: MemoryLayout<UInt32>.size)
        let startCommand = createGaiaCommand(command: 0x46, payload: sizeData)
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(startCommand, characteristic: characteristic)
        }
    }
    
    func sendFile(_ fileData: Data, fileName: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = gaiaCommandCharacteristic else {
            print("File transfer cannot be started")
            return
        }
        let fileType: FileType = (fileName.lowercased().hasSuffix("jpg") ||
                                  fileName.lowercased().hasSuffix("jpeg") ||
                                  fileName.lowercased().hasSuffix("png")) ? .image : .document
        
        currentFileData = fileData
        currentFileName = fileName
        currentFileType = fileType
        fileChunks = prepareChunks(from: fileData, chunkSize: maxGaiaPayloadSize)
        currentChunkIndex = 0
        isFileTransferInProgress = true
        
        var fileInfo = Data()
        fileInfo.append(fileType == .image ? 0x01 : 0x02)
        fileInfo.append(UInt8(fileName.count))
        fileInfo.append(contentsOf: fileName.utf8)
        var sizeBytes = UInt32(fileData.count).littleEndian
        fileInfo.append(contentsOf: withUnsafeBytes(of: sizeBytes) { Data($0) })
        
        let startCommand = createGaiaCommand(command: 0x46, payload: fileInfo)
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(startCommand, characteristic: characteristic)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendGaiaCommand(_ data: Data, characteristic: CBCharacteristic) {
        guard !isWaitingForResponse else {
            print("Waiting for previous GAIA response")
            return
        }
        isWaitingForResponse = true
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    private func prepareChunks(from data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<offset+length)
            chunks.append(chunk)
            offset += length
        }
        print("Prepared \(chunks.count) chunks of size \(chunkSize) bytes")
        return chunks
    }
    
    private func createGaiaCommand(command: UInt8, payload: Data) -> Data {
        var packet = Data([0x10, command])
        let length = UInt16(payload.count).littleEndian
        withUnsafeBytes(of: length) { packet.append(contentsOf: $0) }
        packet.append(payload)
        return packet
    }
    
    private func sendNextFileChunk() {
        guard isFileTransferInProgress,
              currentChunkIndex < fileChunks.count,
              let peripheral = connectedPeripheral,
              let characteristic = gaiaDataCharacteristic else {
            print("Cannot send next file chunk")
            return
        }
        let chunk = fileChunks[currentChunkIndex]
        let chunkCommand = createGaiaCommand(command: 0x47, payload: chunk)
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(chunkCommand, characteristic: characteristic)
        }
    }
    
    private func sendNextImageChunk() {
        guard !imageChunks.isEmpty,
              currentChunkIndex < imageChunks.count,
              let peripheral = connectedPeripheral,
              let characteristic = gaiaDataCharacteristic else {
            print("Cannot send next image chunk")
            return
        }
        let chunk = imageChunks[currentChunkIndex]
        let chunkCommand = createGaiaCommand(command: 0x47, payload: chunk)
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(chunkCommand, characteristic: characteristic)
        }
    }
    
    private func saveTransferredFile() {
        guard let fileData = currentFileData,
              let fileName = currentFileName else {
            print("No file data or filename available")
            return
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try fileData.write(to: fileURL)
            print("File saved at \(fileURL.path)")
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
    
    func handleGaiaResponse(_ data: Data) {
        guard data.count >= 4 else {
            print("Invalid GAIA response")
            return
        }
        let command = data[1]
        let status = data[3]
        print("GAIA response: command=0x\(String(format:"%02X", command)), status=0x\(String(format:"%02X", status))")
        isWaitingForResponse = false
        
        switch command {
        case 0x46:
            if status == 0x00 {
                if isFileTransferInProgress {
                    fileTransferProgress = 0.0
                    sendNextFileChunk()
                }
            } else {
                isFileTransferInProgress = false
                fileChunks.removeAll()
                currentChunkIndex = 0
                currentFileData = nil
                currentFileName = nil
            }
        case 0x47:
            if status == 0x00 {
                currentChunkIndex += 1
                if isFileTransferInProgress {
                    fileTransferProgress = Float(currentChunkIndex) / Float(fileChunks.count)
                    if currentChunkIndex < fileChunks.count {
                        sendNextFileChunk()
                    } else {
                        isFileTransferInProgress = false
                        fileTransferProgress = 1.0
                        saveTransferredFile()
                        fileChunks.removeAll()
                        currentChunkIndex = 0
                        currentFileData = nil
                        currentFileName = nil
                        print("File transfer completed")
                    }
                } else {
                    imageTransferProgress = Float(currentChunkIndex) / Float(imageChunks.count)
                    if currentChunkIndex < imageChunks.count {
                        sendNextImageChunk()
                    } else {
                        isImageTransferInProgress = false
                        imageTransferProgress = 1.0
                        imageChunks.removeAll()
                        currentChunkIndex = 0
                    }
                }
            } else {
                print("Chunk transfer failed with status: \(status)")
                isFileTransferInProgress = false
                fileChunks.removeAll()
                currentChunkIndex = 0
                currentFileData = nil
                currentFileName = nil
            }
        default:
            print("Unknown GAIA response: 0x\(String(format:"%02X", command))")
        }
    }
}
