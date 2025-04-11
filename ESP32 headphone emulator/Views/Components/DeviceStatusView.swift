import SwiftUI

struct DeviceStatusView: View {
    let connectionStatus: String
    let batteryLevel: Double
    let signalStrength: Double
    
    var body: some View {
        VStack(spacing: 15) {
            // Connection Status
            HStack {
                Image(systemName: connectionStatus == "Connected" ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(connectionStatus == "Connected" ? .green : .red)
                    .font(.title2)
                
                Text(connectionStatus)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Battery and Signal Strength
            HStack(spacing: 20) {
                // Battery Indicator
                VStack {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Rectangle()
                                .fill(index < Int(batteryLevel * 5) ? .green : .gray.opacity(0.3))
                                .frame(width: 8, height: 20)
                                .cornerRadius(2)
                        }
                    }
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Signal Strength
                VStack {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { index in
                            Rectangle()
                                .fill(index < Int(signalStrength * 4) ? .blue : .gray.opacity(0.3))
                                .frame(width: 4, height: CGFloat(index + 1) * 5)
                                .cornerRadius(2)
                        }
                    }
                    Text("Signal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack {
        DeviceStatusView(connectionStatus: "Connected", batteryLevel: 0.8, signalStrength: 0.75)
        DeviceStatusView(connectionStatus: "Disconnected", batteryLevel: 0.3, signalStrength: 0.25)
    }
    .padding()
    .background(Color.black)
} 