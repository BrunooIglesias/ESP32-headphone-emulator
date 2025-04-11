//
//  ContentView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: HeadphoneViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Bluetooth Headphone")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connection: \(viewModel.connectionStatus)")
                .font(.title2)
            
            if viewModel.connectionStatus == "Connected" {
                Text("Response: \(viewModel.receivedMessage)")
                    .padding()
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: { viewModel.sendCommand("PLAY") }) {
                        Text("Play")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    Button(action: { viewModel.sendCommand("PAUSE") }) {
                        Text("Pause")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
                HStack(spacing: 20) {
                    Button(action: { viewModel.sendCommand("VOLUME UP") }) {
                        Text("Vol Up")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    Button(action: { viewModel.sendCommand("VOLUME DOWN") }) {
                        Text("Vol Down")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
            } else {
                Text("Scanning for device…")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
    }
}


#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ContentView(viewModel: viewModel)
}
