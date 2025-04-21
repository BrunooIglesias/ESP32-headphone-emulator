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
    @Published var receivedDocument: String? = nil
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    internal var connectedPeripheral: CBPeripheral?
    
    var commandCharacteristic: CBCharacteristic?
    var statusCharacteristic: CBCharacteristic?
    
    var gaiaCommandCharacteristic: CBCharacteristic?
    var gaiaResponseCharacteristic: CBCharacteristic?
    var gaiaDataCharacteristic: CBCharacteristic?
    
    private let commandQueue = DispatchQueue(label: "com.esp32headphone.commandqueue")
    private var isWaitingForResponse = false
    private let maxGaiaPayloadSize = 12
    private var imageChunks: [Data] = []
    private var currentChunkIndex = 0
    internal var documentBuffer = Data()
    
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
              let characteristic = gaiaCommandCharacteristic else {
            print("No GAIA characteristic to receive document")
            return
        }

        isWaitingForResponse = false

        documentBuffer.removeAll()
        receivedDocument = ""
        isDocumentTransferInProgress = false
        documentTransferProgress = 0.0

        let command = createGaiaCommand(command: 0x46, payload: Data([0x02]))
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(command, characteristic: characteristic)
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
                currentChunkIndex = 0
                sendNextImageChunk()
            }
        case 0x47:
            if status == 0x00 {
                currentChunkIndex += 1
                if currentChunkIndex < imageChunks.count {
                    sendNextImageChunk()
                } else {
                    isImageTransferInProgress = false
                    imageTransferProgress = 1.0
                    imageChunks.removeAll()
                    currentChunkIndex = 0
                }
            }
        default:
            print("Unknown GAIA response: 0x\(String(format:"%02X", command))")
        }
    }
}
