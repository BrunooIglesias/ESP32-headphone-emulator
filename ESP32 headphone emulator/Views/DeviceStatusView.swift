import SwiftUI

struct DeviceStatusView: View {
    let connectionStatus: String
    let batteryLevel: Double
    let signalStrength: Double
    
    var body: some View {
        VStack(spacing: 15) {
            StatusRow(
                icon: "wifi",
                title: "Status",
                value: connectionStatus,
                color: connectionStatus == "Connected" ? .green : .red
            )

            StatusRow(
                icon: "battery.100",
                title: "Battery",
                value: "\(Int(batteryLevel * 100))%",
                color: .blue
            )
            
            StatusRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Signal",
                value: "\(Int(signalStrength * 100))%",
                color: .orange
            )
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

private struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    DeviceStatusView(
        connectionStatus: "Connected",
        batteryLevel: 0.75,
        signalStrength: 0.85
    )
    .padding()
    .background(Color.black)
}
