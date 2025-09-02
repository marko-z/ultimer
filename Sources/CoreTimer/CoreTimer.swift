import Foundation

public enum Phase { case work, breakTime }

/// Half-hour boundaries helper
public func nextHalfHourBoundary(from date: Date, calendar: Calendar = .current) -> Date {
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let minute = comps.minute ?? 0
    let add = (minute < 30) ? (30 - minute) : (60 - minute)
    let zeroSec = calendar.date(bySetting: .second, value: 0, of: date) ?? date
    return calendar.date(byAdding: .minute, value: add, to: zeroSec)!
}

/// Engine that runs off real time (no decrementing counters → no drift)
public final class UltimerEngine: ObservableObject {

    // Config (seconds)
    public var workDuration: TimeInterval
    public var breakDuration: TimeInterval

    // State
    @Published public private(set) var currentPhase: Phase
    @Published public private(set) var nextPhaseStart: Date = .now
    @Published public private(set) var timeRemaining: TimeInterval = 0

    // Slot anchors (optional but handy)
    @Published public private(set) var slotStart: Date = .now
    @Published public private(set) var workEnd: Date = .now
    @Published public private(set) var slotEnd: Date = .now

    public init(workMinutes: Int, breakMinutes: Int) {
        self.workDuration = TimeInterval(workMinutes * 60)
        self.breakDuration = TimeInterval(breakMinutes * 60)
    }

    /// Call when the user presses Start (or onAppear). Figures out current phase & next boundary.
    public func start(now: Date = .now, calendar: Calendar = .current) {
        // calculate next half hour boundary and
        slotStart = nextHalfHourBoundary(from: now.addingTimeInterval(-1), calendar: calendar)
        //workEnd = slotStart.addingTimeInterval(workDuration)
        //slotEnd = slotStart.addingTimeInterval(workDuration + breakDuration)
        
        if now <
        if now < slotStart {
            
            nextPhaseStart = slotStart
        } else if now < workEnd {
            currentPhase = .work
            nextPhaseStart = workEnd
        } else if now < slotEnd {
            currentPhase = .breakTime
            nextPhaseStart = slotEnd
        } else {
            // Past slot → start from next slot
            start(now: slotEnd, calendar: calendar)
            return
        }

        // Derive timeRemaining from the clock (no counters)
        timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
    }

    /// Call this every second (or frequently). Recomputes remaining; advances at boundary.
    public func tick(now: Date = .now, calendar: Calendar = .current) {
        timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
        if timeRemaining <= 0 {
            advancePhase(from: now, calendar: calendar)
            timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
        }
    }

    /// Flip phase and set the next boundary.
    public func advancePhase(from now: Date = .now, calendar: Calendar = .current) {
        switch currentPhase {
        case .work:
            currentPhase = .breakTime
            nextPhaseStart = slotEnd  // end of slot

        case .breakTime:
            // Move to the next 30-min slot and re-evaluate
            let nextSlotStart = slotEnd
            slotStart = nextSlotStart
            workEnd = slotStart.addingTimeInterval(workDuration)
            slotEnd = slotStart.addingTimeInterval(workDuration + breakDuration)
            currentPhase = .work
            nextPhaseStart = workEnd
        }
    }

    // Calculation of progress fraction for UI

    public var phaseFraction: Double {
        let total = (currentPhase == .work) ? workDuration : breakDuration
        let elapsed = max(0, total - timeRemaining)
        return min(1, elapsed / total)
    }

    public var slotFraction: Double {
        let total = workDuration + breakDuration
        switch currentPhase {
        case .work:
            return min(1, (workDuration * phaseFraction) / total)
        case .breakTime:
            return min(1, (workDuration + breakDuration * phaseFraction) / total)
        }
    }
}
