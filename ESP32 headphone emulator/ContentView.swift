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
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            GlassButton(title: "Play", action: { viewModel.sendCommand("PLAY") }, color: .green, icon: "play.fill")
                            GlassButton(title: "Pause", action: { viewModel.sendCommand("PAUSE") }, color: .blue, icon: "pause.fill")
                        }
                        
                        HStack(spacing: 20) {
                            GlassButton(title: "Vol Up", action: { viewModel.sendCommand("VOLUME UP") }, color: .orange, icon: "speaker.wave.2.fill")
                            GlassButton(title: "Vol Down", action: { viewModel.sendCommand("VOLUME DOWN") }, color: .red, icon: "speaker.wave.1.fill")
                        }

                        Button(action: { viewModel.disconnect() }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Disconnect")
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    EqualizerView(isPlaying: viewModel.isPlaying)
                        .frame(height: 100)
                        .padding()
                    
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

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
