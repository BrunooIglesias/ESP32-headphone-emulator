//
//  ReceivedMessageView.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/14/25.
//

import SwiftUI

struct ReceivedMessageView: View {
    let message: String
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    ReceivedMessageView(message: "Battery low!")
        .padding()
        .background(Color.black)
}
