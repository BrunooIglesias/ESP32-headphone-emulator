import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var autoConnect = true
    @State private var showNotifications = true
    @State private var selectedTheme = "Dark"
    @State private var volumeStep = 5
    
    let themes = ["Dark", "Light", "System"]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection")) {
                    Toggle("Auto-connect", isOn: $autoConnect)
                    Toggle("Show Notifications", isOn: $showNotifications)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                }
                
                Section(header: Text("Audio")) {
                    Stepper("Volume Step: \(volumeStep)", value: $volumeStep, in: 1...10)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Your Name")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    SettingsView()
} 