import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("theme") private var theme = "Dark"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection")) {
                    Toggle("Auto-connect to last device", isOn: $autoConnect)
                    Toggle("Show connection notifications", isOn: $showNotifications)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $theme) {
                        Text("Dark").tag("Dark")
                        Text("Light").tag("Light")
                        Text("System").tag("System")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
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
