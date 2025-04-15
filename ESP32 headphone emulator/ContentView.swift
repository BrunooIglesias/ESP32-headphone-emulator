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
                    
                    Button(action: {
                        showDocumentTransfer.toggle()
                    }) {
                        Text("Document Transfer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    if viewModel.isDocumentTransferInProgress {
                        ProgressView(value: viewModel.documentTransferProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
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

struct DocumentTransferView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isDocumentTransferInProgress {
                    ProgressView(value: viewModel.documentTransferProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding()
                    
                    Text("Transferring document... \(Int(viewModel.documentTransferProgress * 100))%")
                        .foregroundColor(.gray)
                } else {
                    Button(action: {
                        viewModel.startDocumentTransfer()
                    }) {
                        Text("Start Document Transfer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        viewModel.endDocumentTransfer()
                    }) {
                        Text("End Document Transfer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Document Transfer")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
