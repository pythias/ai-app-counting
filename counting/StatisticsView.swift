import SwiftUI
import Charts

struct CounterStatisticsView: View {
    let counter: CounterItem
    @Environment(\.dismiss) private var dismiss
    
    private var sortedLogs: [CounterLog] {
        counter.logs.sorted { $0.timestamp < $1.timestamp }
    }
    
    private var intervals: [TimeInterval] {
        guard sortedLogs.count > 1 else { return [] }
        var values: [TimeInterval] = []
        for index in 1..<sortedLogs.count {
            values.append(sortedLogs[index].timestamp.timeIntervalSince(sortedLogs[index - 1].timestamp))
        }
        return values
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Overview")) {
                    statRow(title: "Total Count", value: "\(counter.totalCount)")
                }
                
                Section(header: Text("Interval Stats")) {
                    statRow(title: "Fastest", value: formatDuration(intervals.min()))
                    statRow(title: "Slowest", value: formatDuration(intervals.max()))
                    statRow(title: "Average", value: formatDuration(averageInterval))
                }
            }
            .navigationTitle(counter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var averageInterval: TimeInterval? {
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / Double(intervals.count)
    }
    
    private func statRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "-" }
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
}

struct TimerStatisticsView: View {
    let timerItem: TimerItem
    let sessions: [TimerSession]
    @Environment(\.dismiss) private var dismiss
    
    private var sortedSessions: [TimerSession] {
        sessions.sorted { $0.startTime < $1.startTime }
    }
    
    private var sessionTrendData: [(index: Int, duration: TimeInterval)] {
        Array(sortedSessions.enumerated()).map { (offset, session) in
            (index: offset + 1, duration: session.duration)
        }
    }
    
    private var dailyTotals: [(date: Date, duration: TimeInterval)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped
            .map { key, value in
                (date: key, duration: value.reduce(0) { $0 + $1.duration })
            }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Overview")) {
                    statRow(title: "Session Count", value: "\(sessions.count)")
                    statRow(title: "Total Duration", value: formatDuration(sessions.reduce(0) { $0 + $1.duration }))
                }
                
                Section(header: Text("Per Session Trend")) {
                    if sessionTrendData.isEmpty {
                        Text("No data yet")
                            .foregroundColor(.secondary)
                    } else {
                        Chart(sessionTrendData, id: \.index) { point in
                            LineMark(
                                x: .value("Session", point.index),
                                y: .value("Duration", point.duration)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)
                            
                            PointMark(
                                x: .value("Session", point.index),
                                y: .value("Duration", point.duration)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 220)
                    }
                }
                
                Section(header: Text("Daily Total")) {
                    if dailyTotals.isEmpty {
                        Text("No data yet")
                            .foregroundColor(.secondary)
                    } else {
                        Chart(dailyTotals, id: \.date) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Total Duration", item.duration)
                            )
                            .foregroundStyle(.green.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 220)
                    }
                }
            }
            .navigationTitle(timerItem.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func statRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
