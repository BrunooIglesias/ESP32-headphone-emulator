import SwiftUI

struct DeviceStatusView: View {
    let connectionStatus: String
    let batteryLevel: Double
    let signalStrength: Double
    
    var body: some View {
        VStack(spacing: 20) {
            StatusRow(
                icon: "wifi",
                title: "Status",
                value: connectionStatus,
                color: connectionStatus == "Connected" ? .green : .red,
                progress: connectionStatus == "Connected" ? 1.0 : 0.0
            )

            StatusRow(
                icon: "battery.100",
                title: "Battery",
                value: "\(Int(batteryLevel * 100))%",
                color: batteryLevel > 0.2 ? .green : .red,
                progress: batteryLevel
            )
            
            StatusRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Signal",
                value: "\(Int(signalStrength * 100))%",
                color: signalStrength > 0.5 ? .blue : .orange,
                progress: signalStrength
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

private struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let progress: Double
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
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
