import SwiftUI
import SwiftData

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
    @Bindable var counter: CounterItem
    let counters: [CounterItem]
    let onSelect: (UUID) -> Void
    @Environment(\.modelContext) private var modelContext
    
    private var lastIncrementDate: Date? {
        counter.logs
            .filter { $0.delta > 0 }
            .map(\.timestamp)
            .max()
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom)
            
            VStack(spacing: 16) {
                Text(counter.name)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(counter.totalCount)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: counter.totalCount)
                
                VStack(spacing: 4) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        Text(formatElapsedTime(since: lastIncrementDate, now: context.date))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                Text("Tap +1  ·  Long Press -1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            logDelta(1)
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            logDelta(-1)
        }
    }
    
    private func logDelta(_ delta: Int) {
        let newLog = CounterLog(delta: delta, item: counter)
        modelContext.insert(newLog)
        counter.logs.append(newLog)
        counter.lastAccessedAt = Date()
        if delta > 0 {
            ScreenAwakeManager.shared.markCounterActivity()
        }
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
