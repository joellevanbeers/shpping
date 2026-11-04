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

    var currentTask: TaskItem? {
        guard let s = session else { return nil }
        return store.task(s.taskID)
    }

    var minutesLeft: Int {
        guard let s = session else { return 0 }
        return max(0, Int(ceil(s.end.timeIntervalSince(now) / 60)))
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

    func start(taskID: UUID, minutes: Int) {
        let wasRunning = isRunning
        let start = Date()
        store.data.session = Session(taskID: taskID, start: start, end: start.addingTimeInterval(Double(minutes) * 60))
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
        WindowManager.shared.showEnd(taskID: s.taskID)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
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
