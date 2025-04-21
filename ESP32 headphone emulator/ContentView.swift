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
    @State private var showFilePicker = false
    
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
                    
                    Button(action: {
                        viewModel.requestDocument()
                    }) {
                        VStack {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                            Text("Receive Document")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
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
        .sheet(isPresented: $viewModel.showReceivedDocument) {
            if let document = viewModel.receivedDocument {
                DocumentViewer(document: document)
            }
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
