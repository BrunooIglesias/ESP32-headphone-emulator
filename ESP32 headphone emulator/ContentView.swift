//
//  ContentView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import SwiftUI

/// The main view of the application that displays the headphone controls and status
struct ContentView: View {
    // MARK: - Properties
    @StateObject var viewModel: HeadphoneViewModel
    @State private var showSettings = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Main Content
            VStack(spacing: 30) {
                // Header
                Text("ESP32 Headphone")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                // Device Status
                DeviceStatusView(
                    connectionStatus: viewModel.connectionStatus,
                    batteryLevel: viewModel.batteryLevel,
                    signalStrength: viewModel.signalStrength
                )
                
                if viewModel.connectionStatus == "Connected" {
                    // Controls
                    VStack(spacing: 20) {
                        // Playback Controls
                        HStack(spacing: 20) {
                            GlassButton(title: "Play", action: { viewModel.sendCommand("PLAY") }, color: .green, icon: "play.fill")
                            GlassButton(title: "Pause", action: { viewModel.sendCommand("PAUSE") }, color: .blue, icon: "pause.fill")
                        }
                        
                        // Volume Controls
                        HStack(spacing: 20) {
                            GlassButton(title: "Vol Up", action: { viewModel.sendCommand("VOLUME UP") }, color: .orange, icon: "speaker.wave.2.fill")
                            GlassButton(title: "Vol Down", action: { viewModel.sendCommand("VOLUME DOWN") }, color: .red, icon: "speaker.wave.1.fill")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Equalizer Visualization
                    EqualizerView(isPlaying: viewModel.isPlaying)
                        .frame(height: 100)
                        .padding()
                    
                    // Response Message
                    if !viewModel.receivedMessage.isEmpty {
                        Text(viewModel.receivedMessage)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                } else {
                    ScanningView(viewModel: viewModel)
                }
                
                Spacer()
                
                // Settings Button
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Preview
#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
