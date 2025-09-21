// UltimerApp/UltimerApp/ContentView.swift
import SwiftUI
import CoreTimer

struct ContentView: View {
    // Persist work minutes in user defaults
    @AppStorage("workMinutes") private var workMinutes: Int = 20
    private var breakMinutes: Int { max(0, 30 - workMinutes) } // 30-min slot policy

    @StateObject private var engine = UltimerEngine(workMinutes: 20, breakMinutes: 10)

    // 1s tick for countdown; cheap enough for radial too
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let slotSplit = engine.workDuration / (engine.workDuration + engine.breakDuration)

        ZStack {
            // Background color by phase
            (engine.currentPhase == .work ? Color(#colorLiteral(red: 1, green: 0.2317316234, blue: 0.3344128132, alpha: 0.246917517))
                                          : Color.blue.opacity(0.25))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title / phase
                Text(engine.currentPhase == .work ? "Work" : "Break")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Radial
                ZStack {
                    // Base ring
                    Circle().stroke(.secondary.opacity(0.2), lineWidth: 16)

                    // Work arc
                    RingSegment(start: .degrees(-90),
                                end: .degrees(-90 + 360 * slotSplit))
                        .stroke(Color(red: 0.6, green: 0.1, blue: 0.1),
                                style: .init(lineWidth: 16, lineCap: .round))

                    // Break arc
                    RingSegment(start: .degrees(-90 + 360 * slotSplit),
                                end: .degrees(270))
                        .stroke(Color.blue, style: .init(lineWidth: 16, lineCap: .round))

                    // Hand across full 30-min slot
                    Hand(angle: .degrees(-90 + 360 * engine.slotFraction))
                        .stroke(Color.primary, style: .init(lineWidth: 3, lineCap: .round))

                    // Countdown
                    Text(mmss(engine.timeRemaining))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 240, height: 240)

                // Work duration picker (break = 30 - work)
                Picker("Work", selection: $workMinutes) {
                    ForEach([15, 18, 20, 23, 25], id: \.self) { v in
                        Text("\(v)m").tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: workMinutes) { _, new in
                    engine.workDuration  = TimeInterval(new * 60)
                    engine.breakDuration = TimeInterval(max(0, (30 - new) * 60))
                    engine.start() // re-evaluate phase/boundaries now
                }


                // Tiny status line
                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            // Sync engine with current picker values and start
            engine.workDuration  = TimeInterval(workMinutes * 60)
            engine.breakDuration = TimeInterval(max(0, (30 - workMinutes) * 60))
            engine.start()
        }
        .onReceive(tick) { t in
            engine.tick(now: t)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.tick() // catch up after background
            }
        }
    }

    private var statusLine: String {
        let df = DateFormatter(); df.timeStyle = .short
        return "Next: \(df.string(from: engine.nextPhaseStart))"
    }

    private func mmss(_ s: TimeInterval) -> String {
        let v = max(0, Int(s))
        return String(format: "%02d:%02d", v/60, v%60)
    }
}

// MARK: - Shapes

/// Arc from startAngle to endAngle (degrees), clockwise.
struct RingSegment: Shape {
    var start: Angle
    var end: Angle
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height)/2 - 10
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

/// Simple hand from center to ring edge at a given angle.
struct Hand: Shape {
    var angle: Angle
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height)/2 - 10
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rad = CGFloat(angle.radians)
        let end = CGPoint(x: c.x + r * cos(rad), y: c.y + r * sin(rad))
        var p = Path()
        p.move(to: c)
        p.addLine(to: end)
        return p
    }
}

// Put the macro AFTER the struct, with braces:
#Preview {
    ContentView()
}
