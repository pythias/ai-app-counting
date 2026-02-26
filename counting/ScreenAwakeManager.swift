import Foundation
import SwiftUI
import UIKit

@MainActor
final class ScreenAwakeManager {
    static let shared = ScreenAwakeManager()
    
    private let counterDuration: TimeInterval = 5 * 60
    private let timerDuration: TimeInterval = 10 * 60
    
    private var counterDeadline: Date?
    private var timerDeadline: Date?
    private var resetWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func markCounterActivity() {
        counterDeadline = Date().addingTimeInterval(counterDuration)
        reevaluateIdleTimer()
    }
    
    func markTimerStarted() {
        timerDeadline = Date().addingTimeInterval(timerDuration)
        reevaluateIdleTimer()
    }
    
    func markTimerStopped() {
        timerDeadline = nil
        reevaluateIdleTimer()
    }
    
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            reevaluateIdleTimer()
        case .background, .inactive:
            resetWorkItem?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        @unknown default:
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func reevaluateIdleTimer() {
        resetWorkItem?.cancel()
        
        let now = Date()
        if let deadline = counterDeadline, deadline <= now {
            counterDeadline = nil
        }
        if let deadline = timerDeadline, deadline <= now {
            timerDeadline = nil
        }
        
        let nextDeadline = [counterDeadline, timerDeadline].compactMap { $0 }.max()
        guard let nextDeadline else {
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        let delay = max(0, nextDeadline.timeIntervalSince(now))
        let workItem = DispatchWorkItem { [weak self] in
            self?.reevaluateIdleTimer()
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
