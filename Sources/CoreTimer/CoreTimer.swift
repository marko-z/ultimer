import Foundation

public enum Phase { case work, breakTime }

/// Half-hour boundaries helper: returns the *next* XX:00 or XX:30 moment after `date`.
public func nextHalfHourBoundary(from date: Date, calendar: Calendar = .current) -> Date {
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    let minute = comps.minute ?? 0
    // minutes to add to reach the *next* 00 or 30
    let minutesRemaining = (minute < 30) ? (30 - minute) : (60 - minute)

    // zero out seconds first so we don’t carry 12:29:57 -> 12:30:57
    guard let zeroSec = calendar.date(bySetting: .second, value: 0, of: date),
        let bumped = calendar.date(byAdding: .minute, value: minutesRemaining, to: zeroSec)
    else {
        // Fallback: if anything fails, just return date rounded up by 30 min from now
        return date.addingTimeInterval(TimeInterval(minutesRemaining * 60))
    }
    return bumped
}

/// Engine that runs off real time (no decrementing counters → no drift)
public final class UltimerEngine: ObservableObject {

    // Config (seconds)
    public var workDuration: TimeInterval
    public var breakDuration: TimeInterval

    // State
    @Published public private(set) var currentPhase: Phase = .work
    @Published public private(set) var nextPhaseStart: Date = .now
    @Published public private(set) var timeRemaining: TimeInterval = 0

    // Slot anchors (handy for UI/logic)
    @Published public private(set) var workEnd: Date = .now
    @Published public private(set) var slotEnd: Date = .now

    public init(workMinutes: Int, breakMinutes: Int) {
        self.workDuration = TimeInterval(workMinutes * 60)
        self.breakDuration = TimeInterval(breakMinutes * 60)
    }

    /// Called when the user presses Start (or onAppear).
    /// Figures out the slot anchors, current phase, and sets the next boundary.
    public func start(now: Date = .now, calendar: Calendar = .current) {
        // Establish current slot boundaries
        let slotEndCandidate = nextHalfHourBoundary(
            from: now.addingTimeInterval(-1), calendar: calendar)
        let total = workDuration + breakDuration
        slotEnd = slotEndCandidate

        // slotEnd shifted by breakDuration
        workEnd = slotEnd.addingTimeInterval(-breakDuration)

        // Time to the end of slot (in seconds)
        let secondsToBoundary = slotEnd.timeIntervalSince(now)

        // Decide phase by how close we are to slot end
        if secondsToBoundary <= breakDuration {
            // In BREAK: next phase boundary is the end of slot
            currentPhase = .breakTime
            nextPhaseStart = slotEnd
        } else {
            // In WORK: next phase boundary is workEnd (= slotEnd - breakDuration)
            currentPhase = .work
            nextPhaseStart = workEnd
        }

        // Derive remaining from the clock
        timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
    }

    /// Call this every second. Recomputes remaining; advances if boundary reached.
    public func tick(now: Date = .now, calendar: Calendar = .current) {
        timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
        if timeRemaining <= 0 {
            advancePhase(from: now, calendar: calendar)
            timeRemaining = max(0, nextPhaseStart.timeIntervalSince(now))
        }
    }

    /// Flip phase and set the next boundary.
    public func advancePhase(from now: Date = .now, calendar: Calendar = .current) {
        let total = workDuration + breakDuration
        switch currentPhase {
        case .work:
            // Work just ended -> enter BREAK until slotEnd
            currentPhase = .breakTime
            // slot anchors remain; the next boundary is the end of this slot
            nextPhaseStart = slotEnd

        case .breakTime:
            // Break just ended -> roll to NEXT slot and enter WORK
            let nextSlotStart = slotEnd
            workEnd = nextSlotStart.addingTimeInterval(workDuration)
            slotEnd = nextSlotStart.addingTimeInterval(total)

            currentPhase = .work
            nextPhaseStart = workEnd
        }
    }

    // MARK: - Progress values for UI

    /// 0…1 progress within the *current phase*
    public var phaseFraction: Double {
        let total = (currentPhase == .work) ? workDuration : breakDuration
        guard total > 0 else { return 0 }
        let elapsed = max(0, total - timeRemaining)
        return min(1, elapsed / total)
    }

    /// 0…1 across the whole slot (work + break)
    public var slotFraction: Double {
        let total = workDuration + breakDuration
        guard total > 0 else { return 0 }
        switch currentPhase {
        case .work:
            return min(1, (workDuration * phaseFraction) / total)
        case .breakTime:
            return min(1, (workDuration + breakDuration * phaseFraction) / total)
        }
    }
}
