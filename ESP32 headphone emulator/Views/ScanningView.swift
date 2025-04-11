import SwiftUI

struct ScanningView: View {
    @State private var isScanning = false
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Scanning Animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            
            // Scanning Text
            Text("Scanning for devices...")
                .font(.title2)
                .foregroundColor(.white)
            
            // Device List Placeholder
            VStack(spacing: 15) {
                ForEach(0..<3) { i in
                    HStack {
                        Image(systemName: "headphones")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("ESP32 Headphone \(i)")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tap to connect")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
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
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ScanningView()
        .background(Color.black)
} 
