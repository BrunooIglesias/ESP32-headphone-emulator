//
//  BluetoothManager+CBCentralManagerDelegate.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/16/25.
//

import CoreBluetooth

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            isBluetoothAvailable = true
            connectionStatus = "Ready to scan"
            if connectedPeripheral == nil { startScanning() }
        case .poweredOff:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is powered off"
            isScanning = false
        case .resetting:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is resetting"
            isScanning = false
        case .unauthorized:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth is unauthorized"
            isScanning = false
        case .unknown:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth state unknown"
            isScanning = false
        case .unsupported:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth not supported"
            isScanning = false
        @unknown default:
            isBluetoothAvailable = false
            connectionStatus = "Bluetooth unknown state"
            isScanning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        peripheral.delegate = self
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].rssi = RSSI.intValue
            discoveredDevices[index].peripheral = peripheral
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
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionStatus = "Connected"
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = true
        }
        peripheral.discoverServices([
            BluetoothConstants.serviceUUID,
            BluetoothConstants.gaiaServiceUUID
        ])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        connectionStatus = "Connection failed"
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        commandCharacteristic = nil
        statusCharacteristic = nil
        connectionStatus = "Disconnected"
        deviceStatus = nil
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = false
        }
        if central.state == .poweredOn { startScanning() }
    }
}
