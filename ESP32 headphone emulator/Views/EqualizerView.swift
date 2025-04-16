import SwiftUI

struct EqualizerView: View {
    let isPlaying: Bool
    @State private var animationValues: [CGFloat] = Array(repeating: 0.3, count: 5)
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<5) { index in
                EqualizerBar(
                    value: animationValues[index],
                    isPlaying: isPlaying,
                    delay: Double(index) * 0.1
                )
            }
        }
        .frame(height: 100)
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<5 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.1)
            ) {
                animationValues[i] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}

private struct EqualizerBar: View {
    let value: CGFloat
    let isPlaying: Bool
    let delay: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: geometry.size.height)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geometry.size.height * value)
            }
        }
        .opacity(isPlaying ? 1 : 0.5)
    }
}

#Preview {
    EqualizerView(isPlaying: true)
        .padding()
        .background(Color.black)
} 
