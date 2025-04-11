import SwiftUI

/// A view that displays an animated equalizer visualization
struct EqualizerView: View {
    // MARK: - Properties
    let isPlaying: Bool
    @State private var bars: [CGFloat] = Array(repeating: 10, count: 20)
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20) { index in
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 4, height: bars[index])
                    .cornerRadius(2)
            }
        }
        .onAppear {
            generateBars()
        }
        .onChange(of: isPlaying) { _ in
            generateBars()
        }
    }
    
    // MARK: - Private Methods
    private func generateBars() {
        withAnimation(.easeInOut(duration: 0.3)) {
            bars = (0..<20).map { _ in
                isPlaying ? CGFloat.random(in: 10...100) : 10
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EqualizerView(isPlaying: true)
        .frame(height: 100)
        .padding()
        .background(Color.black)
} 