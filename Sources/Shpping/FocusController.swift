import AppKit
import Foundation

/// Beheert de lopende focussessie: timer, focusbalk en de macOS-focusmodus.
@MainActor
final class FocusController: ObservableObject {
    static let shared = FocusController()

    /// Namen van de twee opdrachten (Shortcuts) die de macOS-focusmodus aan/uit zetten.
    nonisolated static let shortcutOn = "Shpping focus aan"
    nonisolated static let shortcutOff = "Shpping focus uit"

    @Published var now = Date()
    private var timer: Timer?
    private let store = Store.shared

    var session: Session? { store.data.session }
    var isRunning: Bool { session != nil }

    /// Alle taken van deze sessie, in volgorde.
    var sessionTasks: [TaskItem] {
        guard let s = session else { return [] }
        return s.taskIDs.compactMap { store.task($0) }
    }

    /// De eerste taak van de sessie die nog niet af is.
    var currentTask: TaskItem? { sessionTasks.first { !$0.done } }

    /// Positie van de huidige taak, bijv. (2, 3) = taak 2 van 3.
    var progress: (current: Int, total: Int) {
        let tasks = sessionTasks
        let done = tasks.filter(\.done).count
        return (min(done + 1, tasks.count), tasks.count)
    }

    var minutesLeft: Int {
        guard let s = session else { return 0 }
        return max(0, Int(ceil(s.end.timeIntervalSince(now) / 60)))
    }

    var secondsLeft: Int {
        guard let s = session else { return 0 }
        return max(0, Int(s.end.timeIntervalSince(now).rounded()))
    }

    /// Hervat een sessie die nog liep toen de app werd afgesloten.
    func resumeIfNeeded() {
        guard let s = session else { return }
        if s.end > Date() {
            startTimer()
            WindowManager.shared.showBar()
        } else {
            store.data.session = nil
            Self.runShortcut(Self.shortcutOff)
        }
    }

    func start(taskIDs: [UUID], minutes: Int) {
        guard !taskIDs.isEmpty else { return }
        let wasRunning = isRunning
        let start = Date()
        store.data.session = Session(taskIDs: taskIDs, start: start, end: start.addingTimeInterval(Double(minutes) * 60))
        now = start
        startTimer()
        WindowManager.shared.showBar()
        if !wasRunning { Self.runShortcut(Self.shortcutOn) }
        refreshMenuIcon()
    }

    /// Rondt de sessie af (tijd is om, of bewust eerder gestopt) en toont het eindscherm.
    func stop() {
        guard let s = session else { return }
        timer?.invalidate()
        timer = nil
        store.data.session = nil
        WindowManager.shared.hideBar()
        Self.runShortcut(Self.shortcutOff)
        refreshMenuIcon()
        NSSound(named: "Glass")?.play()
        WindowManager.shared.showEnd(taskIDs: s.taskIDs)
    }

    /// Vinkt de huidige taak af en gaat door naar de volgende. Laatste taak af = sessie klaar.
    func completeCurrent() {
        guard let t = currentTask else { return }
        store.setDone(t.id, true)
        if currentTask == nil {
            stop()
        } else {
            NSSound(named: "Pop")?.play()
            objectWillChange.send()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in FocusController.shared.tick() }
        }
    }

    private func tick() {
        now = Date()
        if let s = session, now >= s.end { stop() }
    }

    // MARK: macOS-focusmodus via Opdrachten

    nonisolated static func runShortcut(_ name: String) {
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    /// Kijkt of de twee opdrachten bestaan.
    nonisolated static func shortcutsInstalled() -> Bool {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["list"]
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        let names = Set(out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        return names.contains(shortcutOn) && names.contains(shortcutOff)
    }
}
