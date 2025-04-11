//
//  ESP32_headphone_emulatorApp.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import SwiftUI

@main
struct ESP32_headphone_emulatorApp: App {
    let bluetoothManager = BluetoothManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: HeadphoneViewModel(bluetoothManager: bluetoothManager))
        }
    }
}
