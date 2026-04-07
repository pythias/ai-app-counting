import SwiftUI
import SwiftData
import UIKit

struct CounterDirectView: View {
    @Query(sort: \CounterItem.createdAt, order: .reverse) var counters: [CounterItem]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("lastSelectedCounterID") private var lastSelectedCounterID: String = ""
    
    var selectedCounter: CounterItem? {
        if let id = UUID(uuidString: lastSelectedCounterID), let found = counters.first(where: { $0.id == id }) {
            return found
        }
        return counters.first
    }
    
    @State private var showingManagement = false
    @State private var showingCounterStats = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom)
                
                if counters.isEmpty {
                    VStack(spacing: 20) {
                        ContentUnavailableView("No Counters", systemImage: "number.circle", description: Text("Create your first counter to start tracking."))
                        
                        Button(action: addCounterQuick) {
                            Label("Create Counter", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                } else if let counter = selectedCounter {
                    CounterDetailContent(counter: counter, counters: counters) { newID in
                        lastSelectedCounterID = newID.uuidString
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingManagement = true }) {
                        Image(systemName: "list.bullet")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectedCounter != nil {
                            Button(action: { showingCounterStats = true }) {
                                Image(systemName: "chart.xyaxis.line")
                            }
                        }
                        
                        Button(action: addCounterQuick) {
                            Image(systemName: "plus")
                        }
                        
                        Menu {
                            ForEach(counters) { item in
                                Button(action: {
                                    lastSelectedCounterID = item.id.uuidString
                                    item.lastAccessedAt = Date()
                                }) {
                                    HStack {
                                        Text(item.name)
                                        if item.id.uuidString == lastSelectedCounterID {
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
            .sheet(isPresented: $showingCounterStats) {
                if let counter = selectedCounter {
                    CounterStatisticsView(counter: counter)
                }
            }
            .onAppear {
                if counters.isEmpty {
                    let defaultCounter = CounterItem(name: nextAvailableCounterName())
                    modelContext.insert(defaultCounter)
                    lastSelectedCounterID = defaultCounter.id.uuidString
                }
            }
        }
    }
    
    private func addCounterQuick() {
        let counter = CounterItem(name: nextAvailableCounterName())
        modelContext.insert(counter)
        lastSelectedCounterID = counter.id.uuidString
        ScreenAwakeManager.shared.markCounterActivity()
    }
    
    private func nextAvailableCounterName() -> String {
        nextAvailableName(base: NSLocalizedString("My Counter", comment: ""), existingNames: counters.map(\.name))
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

struct CounterDetailContent: View {
    private struct PendingUndoAction {
        let log: CounterLog
        let message: String
        let wasPhaseTiming: Bool
        let previousPhaseStartAt: Date?
        let createdAt: Date
    }
    
    @Bindable var counter: CounterItem
    let counters: [CounterItem]
    let onSelect: (UUID) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isPhaseTiming = false
    @State private var phaseStartAt: Date?
    @State private var isCountPulsing = false
    @State private var isStartButtonPulsing = false
    @State private var pendingUndoActions: [PendingUndoAction] = []
    @State private var isUndoVisible = false
    
    private let undoRetentionSeconds: TimeInterval = 6
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom)
            
            VStack(spacing: 16) {
                Text(counter.name)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 10) {
                    Text("\(counter.totalCount)")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(), value: counter.totalCount)
                        .scaleEffect(isCountPulsing ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.55), value: isCountPulsing)
                    
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        Text(formatElapsedTime(since: currentElapsedStart, now: context.date))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 22)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .contentShape(RoundedRectangle(cornerRadius: 24))
                .gesture(
                    TapGesture()
                        .exclusively(before: LongPressGesture(minimumDuration: 0.35))
                        .onEnded { value in
                            switch value {
                            case .first:
                                incrementAndRestartTiming()
                            case .second:
                                endCurrentPhaseWithLongPress()
                            }
                        }
                )
                
                Text(isPhaseTiming ? "Timing" : "Paused")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isPhaseTiming ? .green : .orange)
                
                if !isPhaseTiming {
                    Button(action: startNextPhaseWithoutCount) {
                        Label("Start Next (+0)", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    .scaleEffect(isStartButtonPulsing ? 1.08 : 1.0)
                    .animation(.spring(response: 0.24, dampingFraction: 0.6), value: isStartButtonPulsing)
                }
                
                VStack(spacing: 4) {
                    Text("Tap +1 restarts timing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Long Press ends current timing (+1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if isUndoVisible {
                HStack(spacing: 12) {
                    Text(undoBannerMessage)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(undoButtonTitle) {
                        undoLastIncrement()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            resetPhaseTimer()
            clearUndoState()
        }
        .onChange(of: counter.id) { _, _ in
            resetPhaseTimer()
            clearUndoState()
        }
    }
    
    private var currentElapsedStart: Date? {
        guard isPhaseTiming else { return nil }
        return phaseStartAt
    }
    
    @discardableResult
    private func logDelta(_ delta: Int) -> CounterLog {
        let newLog = CounterLog(delta: delta, item: counter)
        modelContext.insert(newLog)
        counter.logs.append(newLog)
        counter.lastAccessedAt = Date()
        if delta > 0 {
            ScreenAwakeManager.shared.markCounterActivity()
            playIncrementFeedback()
        }
        return newLog
    }
    
    private func startPhaseTimer() {
        guard !isPhaseTiming else { return }
        isPhaseTiming = true
        phaseStartAt = Date()
    }
    
    private func restartPhaseTimer() {
        isPhaseTiming = true
        phaseStartAt = Date()
    }
    
    private func incrementAndRestartTiming() {
        let previousIsPhaseTiming = isPhaseTiming
        let previousPhaseStartAt = phaseStartAt
        let newLog = logDelta(1)
        restartPhaseTimer()
        showUndo(
            for: newLog,
            message: NSLocalizedString("Added +1", comment: ""),
            wasPhaseTiming: previousIsPhaseTiming,
            previousPhaseStartAt: previousPhaseStartAt
        )
    }
    
    private func endCurrentPhaseWithLongPress() {
        guard isPhaseTiming else { return }
        endPhase()
        playPhaseEndFeedback()
    }
    
    private func endPhase() {
        let previousIsPhaseTiming = isPhaseTiming
        let previousPhaseStartAt = phaseStartAt
        let newLog = logDelta(1)
        resetPhaseTimer()
        showUndo(
            for: newLog,
            message: NSLocalizedString("Ended and added +1", comment: ""),
            wasPhaseTiming: previousIsPhaseTiming,
            previousPhaseStartAt: previousPhaseStartAt
        )
    }
    
    private func startNextPhaseWithoutCount() {
        startPhaseTimer()
        playPhaseStartFeedback()
    }
    
    private func resetPhaseTimer() {
        isPhaseTiming = false
        phaseStartAt = nil
    }
    
    private func playIncrementFeedback() {
        isCountPulsing = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isCountPulsing = false
        }
    }
    
    private func playPhaseEndFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    private func playPhaseStartFeedback() {
        isStartButtonPulsing = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isStartButtonPulsing = false
        }
    }
    
    private func showUndo(for log: CounterLog, message: String, wasPhaseTiming: Bool, previousPhaseStartAt: Date?) {
        pruneExpiredUndoActions()
        pendingUndoActions.append(PendingUndoAction(
            log: log,
            message: message,
            wasPhaseTiming: wasPhaseTiming,
            previousPhaseStartAt: previousPhaseStartAt,
            createdAt: Date()
        ))
        withAnimation(.easeOut(duration: 0.2)) {
            isUndoVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + undoRetentionSeconds) {
            pruneExpiredUndoActions()
        }
    }
    
    private func undoLastIncrement() {
        pruneExpiredUndoActions()
        guard let action = pendingUndoActions.popLast() else { return }
        counter.logs.removeAll { $0.id == action.log.id }
        modelContext.delete(action.log)
        isPhaseTiming = action.wasPhaseTiming
        phaseStartAt = action.previousPhaseStartAt
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if pendingUndoActions.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                isUndoVisible = false
            }
        }
    }
    
    private func clearUndoState() {
        pendingUndoActions.removeAll()
        withAnimation(.easeOut(duration: 0.2)) {
            isUndoVisible = false
        }
    }
    
    private func pruneExpiredUndoActions() {
        let now = Date()
        pendingUndoActions.removeAll { now.timeIntervalSince($0.createdAt) > undoRetentionSeconds }
        if pendingUndoActions.isEmpty, isUndoVisible {
            withAnimation(.easeOut(duration: 0.2)) {
                isUndoVisible = false
            }
        }
    }
    
    private var undoBannerMessage: String {
        pendingUndoActions.last?.message ?? ""
    }
    
    private var undoButtonTitle: String {
        "Undo"
    }
    
    private func formatElapsedTime(since start: Date?, now: Date) -> String {
        guard let start else { return "00:00.0" }
        let elapsed = max(0, now.timeIntervalSince(start))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let tenths = Int((elapsed * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
}
