import Foundation

public enum Phase { case preroll, work, breakTime }

public struct CyclePlan {
    public let slotStart: Date
    public let workEnd: Date
    public let slotEnd: Date
}

public func nextHalfHourBoundary(from date: Date, calendar: Calendar = .current) -> Date {
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let minute = comps.minute ?? 0
    let add = (minute < 30) ? (30 - minute) : (60 - minute)
    let zeroSec = calendar.date(bySetting: .second, value: 0, of: date) ?? date
    return calendar.date(byAdding: .minute, value: add, to: zeroSec)!
}

public func buildCyclePlan(
    now: Date = Date(),
    workMinutes: Int,
    calendar: Calendar = .current
) -> (phase: Phase, plan: CyclePlan) {
    precondition([15, 18, 20, 23, 25].contains(workMinutes))
    let foo = 0;
    print(foo);
    let slotStart = nextHalfHourBoundary(from: now.addingTimeInterval(-1), calendar: calendar)
    let workEnd = calendar.date(byAdding: .minute, value: workMinutes, to: slotStart)!
    let slotEnd = calendar.date(byAdding: .minute, value: 30, to: slotStart)!

    let phase: Phase
    if now < slotStart {
        phase = .preroll
    } else if now < workEnd {
        phase = .work
    } else if now < slotEnd {
        phase = .breakTime
    } else {
        // past the slot; build from next slot
        return buildCyclePlan(now: slotEnd, workMinutes: workMinutes, calendar: calendar)
    }
    return (phase, CyclePlan(slotStart: slotStart, workEnd: workEnd, slotEnd: slotEnd))
}
