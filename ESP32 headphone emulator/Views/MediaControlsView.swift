//
//  MediaControlsView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/14/25.
//

import SwiftUI

struct MediaControlsView: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
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
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return MediaControlsView(viewModel: viewModel)
}
