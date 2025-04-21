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
    @Published var isBluetoothAvailable = false
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
    private var dataChunks: [Data] = []
    private var currentChunkIndex = 0

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
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
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.centralManager.stopScan()
            self.centralManager.scanForPeripherals(withServices: [BluetoothConstants.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func stopScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to device: BluetoothDevice) {
        guard centralManager.state == .poweredOn else { return }
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }), let peripheral = discoveredDevices[index].peripheral {
            stopScanning()
            centralManager.connect(peripheral, options: nil)
        } else if let peripheral = device.peripheral {
            stopScanning()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral, let commandCharacteristic = commandCharacteristic else { return }
        let data = command.data(using: .utf8)!
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
    }

    func requestStatus() {
        sendCommand("GET_STATUS")
    }

    func requestDocument() {
        guard let peripheral = connectedPeripheral, let characteristic = gaiaCommandCharacteristic else { return }

        isWaitingForResponse = false
        receivedDocument = ""

        let command = createGaiaCommand(command: 0x46, payload: Data([0x02]))
        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(command, characteristic: characteristic)
        }
    }

    // MARK: - Helper Methods
    private func sendGaiaCommand(_ data: Data, characteristic: CBCharacteristic) {
        guard !isWaitingForResponse else { return }
        isWaitingForResponse = true
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func createGaiaCommand(command: UInt8, payload: Data) -> Data {
        var packet = Data([0x10, command])
        let length = UInt16(payload.count).littleEndian
        withUnsafeBytes(of: length) { packet.append(contentsOf: $0) }
        packet.append(payload)
        return packet
    }

    private func sendNextDataChunk() {
        guard !dataChunks.isEmpty, currentChunkIndex < dataChunks.count,
              let peripheral = connectedPeripheral,
              let characteristic = gaiaDataCharacteristic else { return }

        let chunk = dataChunks[currentChunkIndex]
        let chunkCommand = createGaiaCommand(command: 0x47, payload: chunk)

        commandQueue.async { [weak self] in
            self?.sendGaiaCommand(chunkCommand, characteristic: characteristic)
        }
    }

    func handleGaiaResponse(_ data: Data) {
        guard data.count >= 4 else { return }

        let command = data[1]
        let status = data[3]
        isWaitingForResponse = false

        switch command {
        case 0x46:
            if status == 0x00 {
                currentChunkIndex = 0
                sendNextDataChunk()
            }
        case 0x47:
            if status == 0x00 {
                currentChunkIndex += 1
                if currentChunkIndex < dataChunks.count {
                    sendNextDataChunk()
                } else {
                    dataChunks.removeAll()
                    currentChunkIndex = 0
                }
            }
        default:
            break
        }
    }
}
