//
//  ContentView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: HeadphoneViewModel
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("ESP32 Headphone")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                DeviceStatusView(
                    connectionStatus: viewModel.connectionStatus,
                    batteryLevel: viewModel.batteryLevel,
                    signalStrength: viewModel.signalStrength
                )
                
                if viewModel.connectionStatus == "Connected" {
                    MediaControlsView(viewModel: viewModel)
                    
                    EqualizerView(isPlaying: viewModel.isPlaying)
                        .frame(height: 100)
                        .padding()
                    
                    if !viewModel.receivedMessage.isEmpty {
                        ReceivedMessageView(message: viewModel.receivedMessage)
                    }
                } else {
                    ScanningView(viewModel: viewModel)
                }
                
                Spacer()
                
                SettingsButton {
                    showSettings.toggle()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
