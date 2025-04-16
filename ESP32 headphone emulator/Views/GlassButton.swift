import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void
    let color: Color
    let icon: String
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.1))
            )
            .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    HStack(spacing: 20) {
        GlassButton(title: "Play", action: {}, color: .green, icon: "play.fill")
        GlassButton(title: "Pause", action: {}, color: .blue, icon: "pause.fill")
    }
    .padding()
    .background(Color.black)
}

