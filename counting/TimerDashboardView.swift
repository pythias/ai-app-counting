import SwiftUI
import SwiftData
internal import Combine

struct TimerDashboardView: View {
    @Query(sort: \TimerSession.startTime, order: .forward) var sessions: [TimerSession]
    @Query(sort: \TimerItem.createdAt, order: .reverse) var timerItems: [TimerItem]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("lastSelectedTimerID") private var lastSelectedTimerID: String = ""
    
    @State private var isRunning = false
    @State private var timeElapsed: TimeInterval = 0
    @State private var startTime: Date?
    @State private var showingManagement = false
    @State private var showingTimerStats = false
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var selectedTimer: TimerItem? {
        if let id = UUID(uuidString: lastSelectedTimerID),
           let found = timerItems.first(where: { $0.id == id }) {
            return found
        }
        return timerItems.first
    }
    
    private var activeTimerTitle: String {
        selectedTimer?.name ?? "Timer"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text(activeTimerTitle.uppercased())
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(2)
                    
                    Text(formatTime(timeElapsed))
                        .font(.system(size: 84, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    
                    Text(isRunning ? "Tap to stop" : "Tap to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Long Press to reset")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleTimer()
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                resetTimer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: ensureDefaultTimer)
            .onReceive(timer) { _ in
                if isRunning {
                    timeElapsed = Date().timeIntervalSince(startTime ?? Date())
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingManagement = true }) {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectedTimer != nil {
                            Button(action: { showingTimerStats = true }) {
                                Image(systemName: "chart.xyaxis.line")
                            }
                        }
                        
                        Button(action: addTimerQuick) {
                            Image(systemName: "plus")
                        }
                        
                        Menu {
                            ForEach(timerItems) { item in
                                Button(action: { selectTimer(item) }) {
                                    HStack {
                                        Text(item.name)
                                        if item.id.uuidString == lastSelectedTimerID {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.body)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingManagement) {
                ManagementView()
            }
            .sheet(isPresented: $showingTimerStats) {
                if let item = selectedTimer {
                    TimerStatisticsView(timerItem: item, sessions: sessions.filter { $0.item?.id == item.id })
                } else {
                    NavigationView {
                        ContentUnavailableView("No Timer Selected", systemImage: "timer", description: Text("Select a timer first."))
                            .navigationTitle("Timer Stats")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
    }
    
    private func toggleTimer() {
        if isRunning {
            let activeItem = selectedTimer
            let session = TimerSession(
                title: activeItem?.name ?? activeTimerTitle,
                startTime: startTime ?? Date(),
                duration: timeElapsed,
                item: activeItem
            )
            modelContext.insert(session)
            ScreenAwakeManager.shared.markTimerStopped()
            isRunning = false
            timeElapsed = 0
        } else {
            ensureDefaultTimer()
            startTime = Date()
            ScreenAwakeManager.shared.markTimerStarted()
            isRunning = true
        }
    }
    
    private func resetTimer() {
        ScreenAwakeManager.shared.markTimerStopped()
        isRunning = false
        timeElapsed = 0
        startTime = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    private func ensureDefaultTimer() {
        guard timerItems.isEmpty else {
            if selectedTimer == nil, let first = timerItems.first {
                lastSelectedTimerID = first.id.uuidString
            }
            return
        }
        let defaultItem = TimerItem(name: nextAvailableTimerName())
        modelContext.insert(defaultItem)
        lastSelectedTimerID = defaultItem.id.uuidString
    }
    
    private func selectTimer(_ item: TimerItem) {
        lastSelectedTimerID = item.id.uuidString
        item.lastAccessedAt = Date()
        resetTimer()
    }
    
    private func addTimerQuick() {
        let item = TimerItem(name: nextAvailableTimerName())
        modelContext.insert(item)
        lastSelectedTimerID = item.id.uuidString
        resetTimer()
    }
    
    private func nextAvailableTimerName() -> String {
        nextAvailableName(base: NSLocalizedString("Plank", comment: ""), existingNames: timerItems.map(\.name))
    }
    
    private func nextAvailableName(base: String, existingNames: [String]) -> String {
        guard existingNames.contains(base) else { return base }
        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}
