import SwiftUI

struct ScanningView: View {
    @ObservedObject var viewModel: HeadphoneViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                    .font(.title)
                
                Text(viewModel.isScanning ? "Scanning for devices..." : "Tap to scan")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            if !viewModel.discoveredDevices.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
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
                Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
        .padding()
    }
}

private struct DeviceRow: View {
    let device: BluetoothDevice
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                Image(systemName: "headphones")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(device.name)
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Text("Signal: \(device.rssi) dBm")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
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
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let viewModel = HeadphoneViewModel(bluetoothManager: bluetoothManager)
    return ScanningView(viewModel: viewModel)
        .padding()
        .background(Color.black)
} 
