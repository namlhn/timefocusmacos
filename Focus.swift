import SwiftUI
import UserNotifications
import AppKit

struct Session: Codable, Identifiable { var id = UUID(); var date: Date; var minutes: Int }
@MainActor final class FocusModel: ObservableObject {
    @Published var duration = 25
    @Published var goal = 120
    @Published var remaining: TimeInterval = 1500
    @Published var running = false
    @Published var isBreak = false
    @Published var sessions: [Session] = []
    @Published var message = "A little progress adds up."
    private var endDate: Date?
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    init() {
        if let data = defaults.data(forKey: "focus.sessions"), let saved = try? JSONDecoder().decode([Session].self, from: data) { sessions = saved }
        let savedGoal = defaults.integer(forKey: "focus.goal"); if savedGoal > 0 { goal = savedGoal }
        duration = max(1, defaults.integer(forKey: "focus.duration") == 0 ? 25 : defaults.integer(forKey: "focus.duration"))
        isBreak = defaults.bool(forKey: "focus.break")
        remaining = defaults.object(forKey: "focus.remaining") as? Double ?? Double(duration * 60)
        if let end = defaults.object(forKey: "focus.end") as? Date { endDate = end; running = true; tick(); if running { startTicker() } }
    }
    var todayMinutes: Int { sessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes } }
    var todayCount: Int { sessions.filter { Calendar.current.isDateInToday($0.date) }.count }
    var total: Double { Double((isBreak ? 5 : duration) * 60) }
    var progress: Double { min(1, max(0, 1 - remaining / total)) }
    var timeText: String { let s = max(0, Int(ceil(remaining))); return String(format: "%02d:%02d", s / 60, s % 60) }
    func select(_ minutes: Int) { guard !running else { return }; isBreak = false; duration = minutes; remaining = Double(minutes * 60); message = "A little progress adds up."; persist() }
    func setGoal(_ value: Int) { goal = value; persist() }
    func toggle() { if running { remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining); running = false; endDate = nil; timer?.invalidate(); message = "Paused. Take your time." } else { if remaining <= 0 { remaining = total }; endDate = Date().addingTimeInterval(remaining); running = true; message = isBreak ? "Take a moment to recharge." : "You're doing great. Stay with it."; startTicker(); UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }; persist() }
    func reset() { timer?.invalidate(); running = false; endDate = nil; remaining = total; message = "Ready when you are."; persist() }
    func breakTime() { timer?.invalidate(); running = false; endDate = nil; isBreak = true; remaining = 300; message = "Step away and recharge."; persist() }
    func focusTime() { timer?.invalidate(); running = false; endDate = nil; isBreak = false; remaining = Double(duration * 60); message = "Ready for another session?"; persist() }
    private func startTicker() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } } }
    private func tick() { guard running, let endDate else { return }; remaining = max(0, endDate.timeIntervalSinceNow); if remaining <= 0 { complete() } }
    private func complete() { timer?.invalidate(); running = false; endDate = nil; remaining = 0; if !isBreak { sessions.append(Session(date: Date(), minutes: duration)); message = "Session complete. Nice work!" } else { message = "Break complete. Ready to focus?" }; persist(); NSSound.beep(); let content = UNMutableNotificationContent(); content.title = isBreak ? "Break complete" : "Focus session complete"; content.body = isBreak ? "Ready for your next focus session?" : "Nice work! Take a moment to recharge."; content.sound = .default; UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) }
    private func persist() { defaults.set(duration, forKey: "focus.duration"); defaults.set(goal, forKey: "focus.goal"); defaults.set(isBreak, forKey: "focus.break"); defaults.set(remaining, forKey: "focus.remaining"); defaults.set(endDate, forKey: "focus.end"); if let data = try? JSONEncoder().encode(sessions) { defaults.set(data, forKey: "focus.sessions") } }
}

struct ContentView: View {
    @ObservedObject var model: FocusModel
    private let purple = Color(red: 0.40, green: 0.34, blue: 0.77)
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) { VStack(alignment: .leading, spacing: 6) { Text("YOUR SPACE TO FOCUS").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple); Text("Make time for what matters.").font(.system(size: 29, weight: .semibold, design: .rounded)); Text("Find your rhythm, one session at a time.").foregroundStyle(.secondary) }; Spacer(); Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(purple).padding(14).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 15)) }
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 20) {
                            HStack { Label(model.isBreak ? "BREAK TIME" : "FOCUS SESSION", systemImage: model.isBreak ? "cup.and.saucer" : "circle.dotted").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(purple); Spacer(); Text(model.running ? "IN PROGRESS" : "YOUR MOMENT").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary) }
                            ZStack { Circle().stroke(Color(red: 0.93, green: 0.92, blue: 0.97), lineWidth: 12); Circle().trim(from: 0, to: model.progress).stroke(purple, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90)); VStack(spacing: 4) { Text(model.timeText).font(.system(size: 52, weight: .light, design: .rounded)).monospacedDigit(); Text(model.isBreak ? "TIME TO RECHARGE" : "TIME TO FOCUS").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.secondary) } }.frame(width: 220, height: 220).padding(.vertical, 5)
                            Text(model.message).font(.system(size: 13)).foregroundStyle(.secondary)
                            HStack(spacing: 10) { Button(action: model.toggle) { Label(model.running ? "Pause session" : "Start session", systemImage: model.running ? "pause.fill" : "play.fill").frame(maxWidth: .infinity).padding(.vertical, 11) }.buttonStyle(PrimaryButton(color: purple)); Button(action: model.reset) { Image(systemName: "arrow.counterclockwise").frame(width: 42, height: 42) }.buttonStyle(QuietButton()).help("Reset timer") }
                            HStack { Text("Duration").font(.system(size: 12, weight: .semibold)); Spacer(); ForEach([25,45,60], id: \.self) { n in Button("\(n) min") { model.select(n) }.buttonStyle(PillButton(selected: !model.isBreak && model.duration == n, color: purple)).disabled(model.running) } }
                            if !model.running { Button(model.isBreak ? "Back to focus" : "Take a 5-minute break") { model.isBreak ? model.focusTime() : model.breakTime() }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(purple) }
                        }.padding(24).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 22))
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Text("Today's progress").font(.system(size: 16, weight: .semibold)); Spacer(); Image(systemName: "chart.bar.fill").foregroundStyle(purple) }
                            Text("\(model.todayMinutes)").font(.system(size: 42, weight: .light, design: .rounded)) + Text("  / \(model.goal) min").font(.system(size: 13)).foregroundColor(.secondary)
                            GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color(red: 0.93, green: 0.92, blue: 0.97)); Capsule().fill(purple).frame(width: g.size.width * min(1, CGFloat(model.todayMinutes) / CGFloat(model.goal))) } }.frame(height: 7)
                            Text(model.todayMinutes >= model.goal ? "Daily goal reached. Well done!" : "Every minute counts. Keep going!").font(.system(size: 12)).foregroundStyle(.secondary)
                            Divider()
                            HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(purple); Text("Sessions completed").font(.system(size: 12)); Spacer(); Text("\(model.todayCount)").fontWeight(.semibold) }
                            HStack { Text("Daily goal").font(.system(size: 12)); Spacer(); Menu("\(model.goal) min") { ForEach([30,60,90,120,180,240], id: \.self) { n in Button("\(n) minutes") { model.setGoal(n) } } }.menuStyle(.borderlessButton).fixedSize() }
                            Spacer(minLength: 8)
                            VStack(alignment: .leading, spacing: 7) { Image(systemName: "lightbulb").foregroundStyle(purple); Text("A gentle reminder").font(.system(size: 13, weight: .semibold)); Text("Small, consistent steps can lead to meaningful progress.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.96, green: 0.95, blue: 0.99), in: RoundedRectangle(cornerRadius: 14))
                        }.padding(22).frame(width: geo.size.width > 700 ? 255 : 210).frame(minHeight: 390).background(.white, in: RoundedRectangle(cornerRadius: 22))
                    }
                    HStack { Image(systemName: "moon.stars"); Text("Make space for focus, and room for rest."); Spacer(); Text("FOCUS  •  REST  •  REPEAT").font(.system(size: 9, weight: .bold)).tracking(1.2) }.font(.system(size: 11)).foregroundStyle(.secondary)
                }.padding(30).frame(maxWidth: 960).frame(maxWidth: .infinity)
            }.background(Color(red: 0.965, green: 0.96, blue: 0.98))
        }.frame(minWidth: 680, minHeight: 650)
    }
}
struct PrimaryButton: ButtonStyle { var color: Color; func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 11)) } }
struct QuietButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.foregroundStyle(.secondary).background(Color.gray.opacity(configuration.isPressed ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 11)) } }
struct PillButton: ButtonStyle { var selected: Bool; var color: Color; func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7).foregroundStyle(selected ? color : .secondary).background(selected ? color.opacity(0.12) : Color.gray.opacity(0.06), in: Capsule()) } }
@main struct FocusApp: App {
    @StateObject private var model = FocusModel()
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        WindowGroup("Focus", id: "main") { ContentView(model: model) }.windowResizability(.contentMinSize)
        MenuBarExtra {
            Text(model.isBreak ? "Break · \(model.timeText)" : "Focus · \(model.timeText)")
            Text(model.message)
            Divider()
            Button(model.running ? "Pause Session" : "Start Session") { model.toggle() }
            Button("Reset Timer") { model.reset() }
            if !model.running {
                Button(model.isBreak ? "Back to Focus" : "Take a 5-Minute Break") {
                    if model.isBreak { model.focusTime() } else { model.breakTime() }
                }
            }
            Divider()
            Text("Today: \(model.todayMinutes) / \(model.goal) minutes")
            Button("Show Focus") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }
            Button("Quit Focus") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.isBreak ? "cup.and.saucer.fill" : "timer")
                if model.running { Text(model.timeText).monospacedDigit() }
            }
        }
    }
}
