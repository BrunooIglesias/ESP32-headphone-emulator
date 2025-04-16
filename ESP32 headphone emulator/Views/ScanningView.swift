import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: isAnimating ? 1 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    
                    Image(systemName: "wifi")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                Text(viewModel.isScanning ? "Scanning for devices..." : "Tap to scan")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if !viewModel.discoveredDevices.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.discoveredDevices) { device in
                            DeviceRow(device: device) {
                                viewModel.connect(to: device)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    viewModel.startScanning()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isScanning ? "stop.fill" : "play.fill")
                    Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding()
        .onChange(of: viewModel.isScanning) { _, newValue in
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                isAnimating = newValue
            }
        }
    }
}

private struct DeviceRow: View {
    let device: BluetoothDevice
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 15) {
                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12))
                        Text("\(device.rssi) dBm")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ScanningView(viewModel: viewModel)
        .padding()
        .background(Color.black)
} 
