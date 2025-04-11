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
    // Published properties to update subscribers (ViewModel)
    @Published var state: CBManagerState = .unknown
    @Published var discoveredPeripheral: CBPeripheral?
    @Published var isConnected: Bool = false
    @Published var receivedValue: String = ""
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    
    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    override init() {
        super.init()
        // Initialize the central manager on the main queue
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Method to send a command to the peripheral
    func sendCommand(_ command: String) {
        guard let peripheral = targetPeripheral,
              let services = peripheral.services else { return }
        
        for service in services where service.uuid == serviceUUID {
            if let characteristics = service.characteristics {
                for characteristic in characteristics where characteristic.uuid == characteristicUUID {
                    if let data = command.data(using: .utf8) {
                        peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    }
                }
            }
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    // Monitor Bluetooth state
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
        print("Bluetooth state updated: \(central.state.rawValue)")
        if central.state == .poweredOn {
            // Start scanning for peripherals with our service
            print("Starting scan for peripherals...")
            centralManager.scanForPeripherals(withServices: [serviceUUID],
                                              options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        } else {
            print("Bluetooth is not available. State: \(central.state.rawValue)")
        }
    }
    
    // Called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        print("Advertisement data: \(advertisementData)")
        if let name = peripheral.name, name.contains("ESP32_Headphone") {
            // Stop scanning once our device is found
            centralManager.stopScan()
            targetPeripheral = peripheral
            discoveredPeripheral = peripheral
            peripheral.delegate = self
            print("Found \(name), connecting now...")
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    // When connected, start discovering services
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        print("Successfully connected to peripheral")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(error?.localizedDescription ?? "No error")")
        isConnected = false
        // Try to reconnect
        centralManager.connect(peripheral, options: nil)
    }
    
    // Discover services on the peripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        print("Discovered services: \(peripheral.services?.map { $0.uuid.uuidString } ?? [])")
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            print("Discovering characteristics for service: \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    // Discover characteristics for each service
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        print("Discovered characteristics: \(service.characteristics?.map { $0.uuid.uuidString } ?? [])")
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            print("Setting up characteristic: \(characteristic.uuid.uuidString)")
            // Subscribe to notifications
            peripheral.setNotifyValue(true, for: characteristic)
            // Optionally read the initial value
            peripheral.readValue(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error setting notification state: \(error.localizedDescription)")
            return
        }
        print("Notification state updated for characteristic: \(characteristic.uuid.uuidString)")
    }
    
    // Called when characteristic value is updated (response from device)
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if characteristic.uuid == characteristicUUID,
           let data = characteristic.value,
           let stringValue = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.receivedValue = stringValue
            }
        }
    }
}
