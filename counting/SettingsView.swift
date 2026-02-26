import SwiftUI

struct SettingsView: View {
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text("Legal")
                }
                
                Section {
                    Picker("Appearance", selection: $appAppearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("Active")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Your counters and timers are stored locally and can sync with iCloud.")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
