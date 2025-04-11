import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void
    let color: Color
    let icon: String
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(color.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    HStack {
        GlassButton(title: "Play", action: {}, color: .green, icon: "play.fill")
        GlassButton(title: "Pause", action: {}, color: .blue, icon: "pause.fill")
    }
    .padding()
    .background(Color.black)
}
