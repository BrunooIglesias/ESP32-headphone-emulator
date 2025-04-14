//
//  HeadphoneViewModel.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import Foundation
import Combine
import SwiftUI

class HeadphoneViewModel: ObservableObject {
    private let bluetoothManager: BluetoothManager
    private var statusUpdateTimer: Timer?
    
    @Published var connectionStatus: String = "Disconnected"
    @Published var receivedMessage: String = ""
    @Published var isPlaying: Bool = false
    @Published var volumeLevel: Int = 50
    @Published var batteryLevel: Double = 0.0
    @Published var signalStrength: Double = 0.0
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning: Bool = false
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        bluetoothManager.$connectionStatus
            .sink { [weak self] status in
                self?.connectionStatus = status
                if status == "Connected" {
                    self?.startStatusUpdates()
                } else if status == "Disconnected" {
                    self?.stopStatusUpdates()
                }
            }
            .store(in: &cancellables)
        
        bluetoothManager.$receivedMessage
            .assign(to: &$receivedMessage)
        
        bluetoothManager.$discoveredDevices
            .assign(to: &$discoveredDevices)
        
        bluetoothManager.$isScanning
            .assign(to: &$isScanning)
        
        bluetoothManager.$deviceStatus
            .sink { [weak self] status in
                guard let status = status else { return }
                DispatchQueue.main.async {
                    self?.isPlaying = status.playing
                    self?.volumeLevel = status.volume
                    self?.batteryLevel = Double(status.battery) / 100.0
                    self?.signalStrength = Double(status.signal) / 100.0
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func startScanning() {
        bluetoothManager.startScanning()
    }
    
    func stopScanning() {
        bluetoothManager.stopScanning()
    }
    
    func connect(to device: BluetoothDevice) {
        print("HeadphoneViewModel: Connecting to device: \(device.name)")
        bluetoothManager.connect(to: device)
    }
    
    func disconnect() {
        print("HeadphoneViewModel: Disconnecting from current device")
        bluetoothManager.disconnect()
    }
    
    func sendCommand(_ command: String) {
        bluetoothManager.sendCommand(command)
    }
    
    func requestStatus() {
        bluetoothManager.requestStatus()
    }
    
    private func startStatusUpdates() {
        requestStatus()
        
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.requestStatus()
        }
    }
    
    private func stopStatusUpdates() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    deinit {
        stopStatusUpdates()
    }
}
