//
//  HeadphoneViewModel.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import Foundation
import Combine

class HeadphoneViewModel: ObservableObject {
    @Published var connectionStatus: String = "Not connected"
    @Published var receivedMessage: String = ""
    
    private var bluetoothManager: BluetoothManager
    private var cancellables = Set<AnyCancellable>()
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Subscribe to updates from BluetoothManager
        bluetoothManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.connectionStatus = connected ? "Connected" : "Not connected"
            }
            .store(in: &cancellables)
        
        bluetoothManager.$receivedValue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.receivedMessage = value
            }
            .store(in: &cancellables)
    }
    
    // Expose sending commands to the view
    func sendCommand(_ command: String) {
        bluetoothManager.sendCommand(command)
    }
}
