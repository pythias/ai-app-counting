import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    
    private var preferredColorScheme: ColorScheme? {
        switch appAppearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CounterDirectView()
                .tabItem {
                    Label("Counter", systemImage: "number.circle.fill")
                }
                .tag(0)
            
            TimerDashboardView()
                .tabItem {
                    Label("Timer", systemImage: "stopwatch.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .preferredColorScheme(preferredColorScheme)
    }
}
