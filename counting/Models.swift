import Foundation
import SwiftData

@Model
final class CounterItem {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastAccessedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \CounterLog.item)
    var logs: [CounterLog] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
    
    var totalCount: Int {
        logs.reduce(0) { $0 + $1.delta }
    }
}

@Model
final class CounterLog {
    var id: UUID
    var timestamp: Date
    var delta: Int
    var item: CounterItem?
    
    init(delta: Int, item: CounterItem) {
        self.id = UUID()
        self.timestamp = Date()
        self.delta = delta
        self.item = item
    }
}

@Model
final class TimerSession {
    var id: UUID
    var title: String
    var startTime: Date
    var duration: TimeInterval
    var item: TimerItem?
    
    init(title: String, startTime: Date, duration: TimeInterval, item: TimerItem? = nil) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.duration = duration
        self.item = item
    }
}

@Model
final class TimerItem {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastAccessedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \TimerSession.item)
    var sessions: [TimerSession] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
}
