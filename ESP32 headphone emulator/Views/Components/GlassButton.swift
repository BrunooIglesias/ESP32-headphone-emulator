import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void
    let color: Color
    let icon: String?
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                Text(title)
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(color.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassButton(title: "Play", action: {}, color: .green, icon: "play.fill")
        GlassButton(title: "Pause", action: {}, color: .blue, icon: "pause.fill")
        GlassButton(title: "Volume Up", action: {}, color: .orange, icon: "speaker.wave.2.fill")
        GlassButton(title: "Volume Down", action: {}, color: .red, icon: "speaker.wave.1.fill")
    }
    .padding()
    .background(Color.black)
} 