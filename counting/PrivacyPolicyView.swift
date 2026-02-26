import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Data We Store") {
                Text("Counting stores your counter and timer records on your device.")
                Text("If iCloud sync is enabled, data may also be synced through your iCloud account.")
            }
            
            Section("Data We Do Not Collect") {
                Text("We do not collect personal identity information.")
                Text("We do not run third-party advertising trackers.")
            }
            
            Section("Your Control") {
                Text("You can delete counters, timers, and records at any time in the app.")
                Text("You can disable iCloud for this app in iOS Settings.")
            }
            
            Section("Contact") {
                Text("If you have privacy questions, please contact the app publisher.")
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
