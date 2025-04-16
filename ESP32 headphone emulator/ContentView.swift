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
                        showFilePicker.toggle()
                    }) {
                        VStack {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 24))
                            Text("Send File")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
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
                    
                    if viewModel.isFileTransferInProgress {
                        VStack {
                            ProgressView(value: viewModel.fileTransferProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            Text("\(Int(viewModel.fileTransferProgress * 100))%")
                                .foregroundColor(.white)
                            Text("Transferring \(viewModel.currentFileType == .image ? "Image" : "Document")")
                                .foregroundColor(.white)
                                .font(.caption)
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
        .sheet(isPresented: $viewModel.showReceivedDocument) {
            if let document = viewModel.receivedDocument {
                DocumentViewer(document: document)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .text, .pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource")
                    return
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    
                    viewModel.sendFile(data, fileName: fileName)
                } catch {
                    print("Error reading file: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
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
