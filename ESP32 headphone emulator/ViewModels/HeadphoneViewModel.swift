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
    @Published var receivedDocument: String? = nil
    @Published var showReceivedDocument: Bool = false

    private var cancellables = Set<AnyCancellable>()

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
            .compactMap { $0 }
            .sink { [weak self] status in
                self?.batteryLevel = Double(status.battery) / 100.0
                self?.signalStrength = Double(status.signal) / 100.0
            }
            .store(in: &cancellables)

        bluetoothManager.$receivedDocument
            .compactMap { $0 }
            .sink { [weak self] document in
                self?.receivedDocument = document
                self?.showReceivedDocument = true
            }
            .store(in: &cancellables)
    }

    func startScanning() {
        bluetoothManager.startScanning()
    }

    func stopScanning() {
        bluetoothManager.stopScanning()
    }

    func connect(to device: BluetoothDevice) {
        bluetoothManager.connect(to: device)
    }

    func disconnect() {
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

        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0,
                                                 repeats: true) { [weak self] _ in
            self?.requestStatus()
        }
    }

    private func stopStatusUpdates() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }

    func requestDocument() {
        bluetoothManager.requestDocument()
    }

    deinit {
        stopStatusUpdates()
    }
}
