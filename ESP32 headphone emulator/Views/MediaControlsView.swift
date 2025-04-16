//
//  MediaControlsView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/14/25.
//

import SwiftUI

struct MediaControlsView: View {
    let viewModel: HeadphoneViewModel
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 25) {
            HStack(spacing: 30) {
                ControlButton(
                    action: { viewModel.sendCommand("PLAY") },
                    icon: "play.fill",
                    color: .green,
                    size: .large
                )
                
                ControlButton(
                    action: { viewModel.sendCommand("PAUSE") },
                    icon: "pause.fill",
                    color: .blue,
                    size: .large
                )
            }
            
            HStack(spacing: 30) {
                ControlButton(
                    action: { viewModel.sendCommand("VOLUME UP") },
                    icon: "speaker.wave.2.fill",
                    color: .orange,
                    size: .medium
                )
                
                ControlButton(
                    action: { viewModel.sendCommand("VOLUME DOWN") },
                    icon: "speaker.wave.1.fill",
                    color: .red,
                    size: .medium
                )
            }
            
            Button(action: { viewModel.disconnect() }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Disconnect")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal)
    }
}

private struct ControlButton: View {
    let action: () -> Void
    let icon: String
    let color: Color
    let size: ButtonSize
    
    enum ButtonSize {
        case large
        case medium
        
        var dimensions: CGFloat {
            switch self {
            case .large: return 80
            case .medium: return 60
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .large: return 30
            case .medium: return 24
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size.dimensions, height: size.dimensions)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return MediaControlsView(viewModel: viewModel)
        .padding()
        .background(Color.black)
}
