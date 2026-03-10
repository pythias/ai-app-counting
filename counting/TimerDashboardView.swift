import SwiftUI
import SwiftData
internal import Combine
import UIKit

private enum TimerDisplayStyle: String, CaseIterable, Identifiable {
    case digital
    case clock
    
    var id: String { rawValue }
}

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
    @State private var selectedStyleIndex = 0
    @State private var isTimePulsing = false
    
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
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom)
                
                VStack(spacing: 24) {
                    Text(activeTimerTitle.uppercased())
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(2)
                    
                    TabView(selection: $selectedStyleIndex) {
                        ForEach(Array(TimerDisplayStyle.allCases.enumerated()), id: \.offset) { index, style in
                            timerStyleCard(style: style)
                                .tag(index)
                        }
                    }
                    .frame(height: 280)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    HStack(spacing: 6) {
                        ForEach(0..<TimerDisplayStyle.allCases.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedStyleIndex ? Color.blue : Color.secondary.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .padding(44)
                .frame(maxWidth: .infinity)
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
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear(perform: ensureDefaultTimer)
            .onReceive(timer) { _ in
                if isRunning {
                    timeElapsed = Date().timeIntervalSince(startTime ?? Date())
                }
            }
            .onChange(of: selectedStyleIndex) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
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
                    NavigationStack {
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isRunning = false
            timeElapsed = 0
        } else {
            ensureDefaultTimer()
            startTime = Date()
            ScreenAwakeManager.shared.markTimerStarted()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            pulseTime()
            isRunning = true
        }
    }
    
    private func resetTimer() {
        ScreenAwakeManager.shared.markTimerStopped()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        isRunning = false
        timeElapsed = 0
        startTime = nil
    }
    
    @ViewBuilder
    private func timerStyleCard(style: TimerDisplayStyle) -> some View {
        switch style {
        case .digital:
            VStack(spacing: 14) {
                Text(formatTime(timeElapsed))
                    .font(.system(size: 82, weight: .light, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .scaleEffect(isTimePulsing ? 1.04 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isTimePulsing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
            .background(cardBackground)
        case .clock:
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    clockHands
                }
                .frame(width: 180, height: 180)
                Text(formatTime(timeElapsed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
            .background(cardBackground)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }
    
    private var progressFraction: CGFloat {
        CGFloat((timeElapsed.truncatingRemainder(dividingBy: 60)) / 60.0)
    }
    
    private var clockHands: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let secondAngle = Angle.degrees((timeElapsed.truncatingRemainder(dividingBy: 60) / 60.0) * 360)
            let minuteAngle = Angle.degrees((timeElapsed.truncatingRemainder(dividingBy: 3600) / 3600.0) * 360)
            
            ZStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: 3, height: size * 0.25)
                    .offset(y: -size * 0.125)
                    .rotationEffect(minuteAngle)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: size * 0.34)
                    .offset(y: -size * 0.17)
                    .rotationEffect(secondAngle)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 9, height: 9)
            }
            .position(center)
        }
    }
    
    private func pulseTime() {
        isTimePulsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isTimePulsing = false
        }
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
