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
    @State private var showMessage = false
    @State private var showDocumentTransfer = false
    @State private var showImageTransfer = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("ESP32 Headphone")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                DeviceStatusView(
                    connectionStatus: viewModel.connectionStatus,
                    batteryLevel: Double(viewModel.batteryLevel),
                    signalStrength: Double(viewModel.signalStrength)
                )
                
                if viewModel.connectionStatus == "Connected" {
                    MediaControlsView(viewModel: viewModel)
                    
                    EqualizerView(isPlaying: viewModel.isPlaying)
                        .frame(height: 100)
                        .padding()
                    
                    HStack(spacing: 20) {
                        DocumentTransferButton(viewModel: viewModel)
                        
                        Button(action: {
                            showImageTransfer.toggle()
                        }) {
                            VStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 24))
                                Text("Send Image")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isImageTransferInProgress {
                        VStack {
                            ProgressView(value: viewModel.imageTransferProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            Text("\(Int(viewModel.imageTransferProgress * 100))%")
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                } else {
                    ScanningView(viewModel: viewModel)
                }
                
                Spacer()
                
                SettingsButton {
                    showSettings.toggle()
                }
            }
            .padding(.top, 20)
            .padding(.horizontal)
            
            if showMessage && !viewModel.receivedMessage.isEmpty {
                VStack {
                    Spacer()
                    ReceivedMessageView(message: viewModel.receivedMessage)
                        .padding(.bottom, 80)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: showMessage)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showDocumentTransfer) {
            DocumentTransferView(viewModel: viewModel)
        }
        .sheet(isPresented: $showImageTransfer) {
            ImageTransferView(viewModel: viewModel)
        }
        .onChange(of: viewModel.receivedMessage) { oldValue, newValue in
            guard newValue != oldValue, !newValue.isEmpty else { return }
            showMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showMessage = false
                }
            }
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
