//
//  SettingsButton.swift
//  ESP32 headphone emulator
//
//  Created by Bruno Sebastian Silva Iglesias on 4/14/25.
//

import SwiftUI

struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    SettingsButton {
        print("Settings tapped")
    }
}
