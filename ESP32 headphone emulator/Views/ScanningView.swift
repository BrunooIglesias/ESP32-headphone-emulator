import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Scanning Animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            
            // Scanning Text
            Text(viewModel.isScanning ? "Scanning for devices..." : "No devices found")
                .font(.title2)
                .foregroundColor(.white)
            
            // Device List
            if !viewModel.discoveredDevices.isEmpty {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(viewModel.discoveredDevices) { device in
                            DeviceRow(device: device) {
                                viewModel.connect(to: device)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Scan Button
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    viewModel.startScanning()
                }
            }) {
                Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            viewModel.startScanning()
        }
    }
}

struct DeviceRow: View {
    let device: BluetoothDevice
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                Image(systemName: "headphones")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Signal: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if device.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ScanningView(viewModel: viewModel)
        .background(Color.black)
} 
