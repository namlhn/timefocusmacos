import SwiftUI
import AppKit

struct FocusTask: Codable, Identifiable { var id = UUID(); var title: String; var done = false }
struct Session: Codable, Identifiable { var id = UUID(); var date: Date; var minutes: Int }
@MainActor final class FocusModel: ObservableObject {
    @Published var duration = 25
    @Published var goal = 120
    @Published var remaining: TimeInterval = 1500
    @Published var running = false
    @Published var isBreak = false
    @Published var sessions: [Session] = []
    @Published var tasks: [FocusTask] = []
    @Published var message = "A little progress adds up."
    private var endDate: Date?
    private var timer: Timer?
    private var nextRestReminder: TimeInterval = 1200
    private let defaults = UserDefaults.standard
    init() {
        if let data = defaults.data(forKey: "focus.sessions"), let saved = try? JSONDecoder().decode([Session].self, from: data) { sessions = saved }
        if let data = defaults.data(forKey: "focus.tasks"), let saved = try? JSONDecoder().decode([FocusTask].self, from: data) { tasks = saved }
        let savedGoal = defaults.integer(forKey: "focus.goal"); if savedGoal > 0 { goal = savedGoal }
        duration = max(1, defaults.integer(forKey: "focus.duration") == 0 ? 25 : defaults.integer(forKey: "focus.duration"))
        isBreak = defaults.bool(forKey: "focus.break")
        remaining = defaults.object(forKey: "focus.remaining") as? Double ?? Double(duration * 60)
        nextRestReminder = defaults.object(forKey: "focus.nextRestReminder") as? Double ?? (floor(max(0, total - remaining) / 1200) + 1) * 1200
        if let end = defaults.object(forKey: "focus.end") as? Date { endDate = end; running = true; tick(); if running { startTicker() } }
    }
    var todayMinutes: Int { sessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes } }
    var todayCount: Int { sessions.filter { Calendar.current.isDateInToday($0.date) }.count }
    var total: Double { Double((isBreak ? 5 : duration) * 60) }
    var progress: Double { min(1, max(0, 1 - remaining / total)) }
    var timeText: String { let s = max(0, Int(ceil(remaining))); return String(format: "%02d:%02d", s / 60, s % 60) }
    func select(_ minutes: Int) { guard !running else { return }; isBreak = false; duration = minutes; remaining = Double(minutes * 60); nextRestReminder = 1200; message = "A little progress adds up."; persist() }
    func addTask(_ title: String) { let clean = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }; tasks.append(FocusTask(title: clean)); persist() }
    func toggleTask(_ id: UUID) { guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }; tasks[index].done.toggle(); persist() }
    func deleteTask(_ id: UUID) { tasks.removeAll { $0.id == id }; persist() }
    func setGoal(_ value: Int) { goal = value; persist() }
    func toggle() { if running { remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining); running = false; endDate = nil; timer?.invalidate(); message = "Paused. Take your time." } else { if remaining <= 0 { remaining = total; nextRestReminder = 1200 }; endDate = Date().addingTimeInterval(remaining); running = true; message = isBreak ? "Take a moment to recharge." : "You're doing great. Stay with it."; startTicker() }; persist() }
    func reset() { timer?.invalidate(); running = false; endDate = nil; remaining = total; nextRestReminder = 1200; message = "Ready when you are."; persist() }
    func breakTime() { timer?.invalidate(); running = false; endDate = nil; isBreak = true; remaining = 300; nextRestReminder = 1200; message = "Step away and recharge."; persist() }
    func focusTime() { timer?.invalidate(); running = false; endDate = nil; isBreak = false; remaining = Double(duration * 60); nextRestReminder = 1200; message = "Ready for another session?"; persist() }
    private func startTicker() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } } }
    private func tick() {
        guard running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { complete(); return }
        let elapsed = total - remaining
        if !isBreak && elapsed >= nextRestReminder {
            nextRestReminder = (floor(elapsed / 1200) + 1) * 1200
            message = "Time to stand up and move around."
            persist()
            alert(title: "Time for a little break", body: "You've been focusing for 20 minutes. Stand up, stretch, and move around for a moment.")
        }
    }
    private func alert(title: String, body: String) {
        DispatchQueue.main.async {
            NSSound.beep()
            NSApp.requestUserAttention(.informationalRequest)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    private func complete() {
        timer?.invalidate(); running = false; endDate = nil; remaining = 0
        if !isBreak { sessions.append(Session(date: Date(), minutes: duration)); message = "Session complete. Nice work!" }
        else { message = "Break complete. Ready to focus?" }
        persist()
        alert(title: isBreak ? "Break complete" : "Focus session complete", body: isBreak ? "Ready for your next focus session?" : "Nice work! Take a moment to recharge.")
    }
    private func persist() { defaults.set(nextRestReminder, forKey: "focus.nextRestReminder"); defaults.set(duration, forKey: "focus.duration"); defaults.set(goal, forKey: "focus.goal"); defaults.set(isBreak, forKey: "focus.break"); defaults.set(remaining, forKey: "focus.remaining"); defaults.set(endDate, forKey: "focus.end"); if let data = try? JSONEncoder().encode(sessions) { defaults.set(data, forKey: "focus.sessions") }; if let data = try? JSONEncoder().encode(tasks) { defaults.set(data, forKey: "focus.tasks") } }
}

struct ContentView: View {
    @ObservedObject var model: FocusModel
    @State private var newTask = ""
    @State private var showTasks = false
    private let ink = Color(red: 0.14, green: 0.16, blue: 0.20)
    private let muted = Color(red: 0.39, green: 0.41, blue: 0.45)
    private let accent = Color(red: 0.35, green: 0.32, blue: 0.70)
    private let surface = Color(red: 0.97, green: 0.96, blue: 0.94)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "circle.dotted.circle.fill").font(.system(size: 20)).foregroundStyle(accent)
                    Text("focus").font(.system(size: 20, weight: .bold, design: .rounded)).tracking(-0.5)
                }
                Spacer()
                Button { showTasks.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checklist")
                        Text("Tasks")
                        if !model.tasks.isEmpty { Text("\(model.tasks.filter { !$0.done }.count)").foregroundStyle(muted) }
                    }.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 13).frame(height: 36)
                }.buttonStyle(OutlineButton()).popover(isPresented: $showTasks, arrowEdge: .bottom) { taskList }
            }.padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 18)
            Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        modeButton("Focus", selected: !model.isBreak) { if model.isBreak { model.focusTime() } }
                        modeButton("Break", selected: model.isBreak) { if !model.isBreak { model.breakTime() } }
                    }.padding(4).background(ink.opacity(0.055), in: Capsule()).disabled(model.running)
                    Spacer(minLength: 18)
                    ZStack {
                        Circle().stroke(ink.opacity(0.07), lineWidth: 7)
                        Circle().trim(from: 0, to: model.progress).stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 5) {
                            Text(model.timeText).font(.system(size: 62, weight: .light, design: .rounded)).monospacedDigit().tracking(-2)
                            Text(model.running ? (model.isBreak ? "TAKE A BREATH" : "STAY IN THE MOMENT") : (model.remaining <= 0 ? "SESSION COMPLETE" : "READY WHEN YOU ARE"))
                                .font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(muted)
                        }
                    }.frame(width: 228, height: 228).accessibilityElement(children: .combine)
                    Spacer(minLength: 18)
                    HStack(spacing: 10) {
                        Button(action: model.toggle) {
                            Label(model.running ? "Pause session" : (model.isBreak ? "Start break" : "Start focusing"), systemImage: model.running ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity).frame(height: 46)
                        }.buttonStyle(FilledButton(color: accent))
                        Button(action: model.reset) { Image(systemName: "arrow.counterclockwise").frame(width: 46, height: 46) }
                            .buttonStyle(OutlineButton()).help("Reset timer").accessibilityLabel("Reset timer")
                    }.frame(maxWidth: 300)
                    Text(model.message).font(.system(size: 12)).foregroundStyle(muted).lineLimit(1).padding(.top, 14).frame(height: 31)
                }.padding(.horizontal, 32).padding(.vertical, 22).frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(ink.opacity(0.08)).frame(width: 1)
                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR SESSION").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(muted)
                    Text("Focus duration").font(.system(size: 15, weight: .semibold)).padding(.top, 20)
                    Text("Choose a pace that feels right.").font(.system(size: 12)).foregroundStyle(muted).padding(.top, 5)
                    HStack(spacing: 6) {
                        ForEach([25, 45, 60], id: \.self) { minutes in
                            Button("\(minutes)m") { model.select(minutes) }
                                .buttonStyle(DurationButton(selected: model.duration == minutes && !model.isBreak, accent: accent))
                        }
                    }.padding(.top, 15).disabled(model.running || model.isBreak)
                    HStack(spacing: 8) {
                        Text("Custom").font(.system(size: 12)).foregroundStyle(muted)
                        Spacer()
                        Button { model.select(max(1, model.duration - 1)) } label: { Image(systemName: "minus").frame(width: 30, height: 30) }
                            .buttonStyle(OutlineButton()).disabled(model.running || model.isBreak || model.duration <= 1).help("Decrease duration")
                        Text("\(model.duration) min").font(.system(size: 12, weight: .semibold)).monospacedDigit().frame(width: 50)
                        Button { model.select(min(240, model.duration + 1)) } label: { Image(systemName: "plus").frame(width: 30, height: 30) }
                            .buttonStyle(OutlineButton()).disabled(model.running || model.isBreak || model.duration >= 240).help("Increase duration")
                    }.padding(.top, 12)
                    Rectangle().fill(ink.opacity(0.08)).frame(height: 1).padding(.vertical, 24)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Today").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Menu { ForEach([30, 60, 90, 120, 180, 240], id: \.self) { n in Button("\(n) minutes") { model.setGoal(n) } } } label: {
                            Text("Goal: \(model.goal) min")
                        }.menuStyle(.borderlessButton).fixedSize().font(.system(size: 11)).help("Change daily goal")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(model.todayMinutes)").font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                        Text("/ \(model.goal) min").font(.system(size: 12)).foregroundStyle(muted)
                    }.padding(.top, 12)
                    GeometryReader { geo in ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.08))
                        Capsule().fill(accent).frame(width: geo.size.width * min(1, CGFloat(model.todayMinutes) / CGFloat(model.goal)))
                    } }.frame(height: 5).padding(.top, 10)
                    Text("\(model.todayCount) \(model.todayCount == 1 ? "session" : "sessions") completed").font(.system(size: 11)).foregroundStyle(muted).padding(.top, 9)
                    Spacer(minLength: 20)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "figure.walk").foregroundStyle(accent)
                        Text("A reminder to move every 20 minutes.").font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }.padding(25).frame(width: 270).frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }.foregroundStyle(ink).background(surface).frame(minWidth: 720, minHeight: 540)
    }
    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 12, weight: .semibold)).frame(width: 75, height: 30).background(selected ? Color.white : Color.clear, in: Capsule()).foregroundStyle(selected ? ink : muted) }.buttonStyle(.plain)
    }
    private var taskList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Tasks").font(.system(size: 17, weight: .semibold)); Spacer(); Text("\(model.tasks.filter { $0.done }.count)/\(model.tasks.count)").foregroundStyle(.secondary) }
            HStack {
                TextField("Add a task", text: $newTask).textFieldStyle(.roundedBorder).onSubmit(addTask)
                Button(action: addTask) { Image(systemName: "plus") }.disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).help("Add task")
            }
            if model.tasks.isEmpty { Text("Add something you want to work on.").font(.system(size: 12)).foregroundStyle(.secondary) }
            ScrollView { VStack(alignment: .leading, spacing: 10) {
                ForEach(model.tasks) { task in
                    HStack(alignment: .top, spacing: 8) {
                        Button { model.toggleTask(task.id) } label: { Image(systemName: task.done ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain).foregroundStyle(accent).help(task.done ? "Mark incomplete" : "Mark complete")
                        Text(task.title).strikethrough(task.done).frame(maxWidth: .infinity, alignment: .leading)
                        Button { model.deleteTask(task.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Delete task")
                    }.font(.system(size: 12))
                }
            } }.frame(maxHeight: 220)
        }.padding(20).frame(width: 300)
    }
    private func addTask() { model.addTask(newTask); newTask = "" }
}
struct FilledButton: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(Color(red: 0.22, green: 0.23, blue: 0.27))
            .background(Color.white.opacity(configuration.isPressed ? 0.5 : 0.8), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.black.opacity(0.08)))
    }
}
struct DurationButton: ButtonStyle {
    var selected: Bool
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 34)
            .foregroundStyle(selected ? accent : Color(red: 0.25, green: 0.26, blue: 0.30))
            .background(selected ? accent.opacity(0.12) : Color.white.opacity(configuration.isPressed ? 0.5 : 0.8), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? accent.opacity(0.4) : Color.black.opacity(0.08)))
    }
}
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
