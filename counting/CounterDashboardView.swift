import SwiftUI
import SwiftData

struct CounterDashboardView: View {
    @Query(sort: \CounterItem.createdAt, order: .reverse) var counters: [CounterItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddCounter = false
    @State private var newCounterName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if counters.isEmpty {
                    ContentUnavailableView("No Counters", systemImage: "number.circle", description: Text("Add a new counter to get started (e.g., 'Run Baal')"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(counters) { counter in
                                NavigationLink(destination: CounterDetailView(counter: counter)) {
                                    CounterRow(counter: counter)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Counters")
            .toolbar {
                Button(action: { showingAddCounter = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            .sheet(isPresented: $showingAddCounter) {
                NavigationView {
                    Form {
                        TextField("Counter Name", text: $newCounterName)
                    }
                    .navigationTitle("New Counter")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddCounter = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let newCounter = CounterItem(name: newCounterName)
                                modelContext.insert(newCounter)
                                newCounterName = ""
                                showingAddCounter = false
                            }
                            .disabled(newCounterName.isEmpty)
                        }
                    }
                }
            }
        }
    }
}

struct CounterRow: View {
    let counter: CounterItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(counter.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Last updated: \(counter.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(counter.totalCount)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

import SwiftUI
import SwiftData
import Charts

// ... (CounterDashboardView and CounterRow remain the same)

struct CounterDetailView: View {
    @Bindable var counter: CounterItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack {
                    Text(counter.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Total Run Count")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Text("\(counter.totalCount)")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: counter.totalCount)
                
                HStack(spacing: 30) {
                    Button(action: { logDelta(-1) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }
                    .shadow(color: .red.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Button(action: { logDelta(1) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                // Activity Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Activity")
                        .font(.headline)
                    
                    Chart {
                        ForEach(dailyData, id: \.date) { data in
                            BarMark(
                                x: .value("Day", data.date, unit: .day),
                                y: .value("Count", data.count)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 180)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(counter.logs.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10)) { log in
                            HStack {
                                Label(log.delta > 0 ? "Added \(log.delta)" : "Subtracted \(abs(log.delta))", systemImage: log.delta > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundColor(log.delta > 0 ? .green : .red)
                                Spacer()
                                Text(log.timestamp.formatted(date: .numeric, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            if log.id != counter.logs.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10).last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
    
    private func logDelta(_ delta: Int) {
        let newLog = CounterLog(delta: delta, item: counter)
        modelContext.insert(newLog)
        counter.logs.append(newLog)
    }
    
    // Aggregated daily data for the chart
    private var dailyData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let last7Days = (0...6).map { calendar.date(byAdding: .day, value: -$0, to: now)! }.reversed()
        
        return last7Days.map { day in
            let count = counter.logs
                .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
                .reduce(0) { $0 + $1.delta }
            return (date: day, count: count)
        }
    }
}
