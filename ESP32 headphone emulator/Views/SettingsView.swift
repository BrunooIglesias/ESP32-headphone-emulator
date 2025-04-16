import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("theme") private var theme = "Dark"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsSection(title: "Connection") {
                        SettingsToggleRow(
                            icon: "link.circle.fill",
                            title: "Auto-connect",
                            subtitle: "Automatically connect to last device",
                            isOn: $autoConnect,
                            color: .blue
                        )
                        
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            subtitle: "Show connection notifications",
                            isOn: $showNotifications,
                            color: .orange
                        )
                    }
                    
                    SettingsSection(title: "Appearance") {
                        SettingsPickerRow(
                            icon: "paintbrush.fill",
                            title: "Theme",
                            selection: $theme,
                            options: ["Dark", "Light", "System"],
                            color: .purple
                        )
                    }
                    
                    SettingsSection(title: "About") {
                        SettingsInfoRow(
                            icon: "info.circle.fill",
                            title: "Version",
                            value: "1.0.0",
                            color: .green
                        )
                        
                        SettingsInfoRow(
                            icon: "number.circle.fill",
                            title: "Build",
                            value: "1",
                            color: .red
                        )
                    }
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

private struct SettingsPickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: String
    let options: [String]
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .padding()
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
}

#Preview {
    SettingsView()
} 
