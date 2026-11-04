import Foundation
import SwiftUI

// MARK: - Modellen

struct TaskItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var day: String          // yyyy-MM-dd, de dag waarvoor de taak gepland is
    var done = false
    var dropped = false      // bewust laten vallen bij de dagstart
    var order: Int
}

struct Thought: Codable, Identifiable, Equatable {
    enum Status: String, Codable { case new, later }
    var id = UUID()
    var text: String
    var created = Date()
    var status: Status = .new
}

struct Session: Codable, Equatable {
    var taskID: UUID
    var start: Date
    var end: Date
}

struct AppData: Codable {
    var tasks: [TaskItem] = []
    var thoughts: [Thought] = []
    var lastDayStart: String? = nil
    var session: Session? = nil
}

// MARK: - Kleuren (Growthentic-huisstijl)

extension Color {
    static let ink = Color(red: 0x22/255, green: 0x1C/255, blue: 0x2B/255)
    static let ink2 = Color(red: 0x2E/255, green: 0x26/255, blue: 0x38/255)
    static let wine = Color(red: 0x63/255, green: 0x32/255, blue: 0x48/255)
    static let tech = Color(red: 0x8F/255, green: 0xC1/255, blue: 0xBC/255)
    static let muted = Color(red: 0x6B/255, green: 0x67/255, blue: 0x72/255)
}

// MARK: - Opslag

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var data = AppData() {
        didSet { save() }
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shpping", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    private init() {
        if let raw = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(AppData.self, from: raw) {
                data = decoded
            }
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? encoder.encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    // MARK: Dagen

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var today: String { Store.dayKey() }

    // MARK: Taken

    var todayTasks: [TaskItem] {
        data.tasks.filter { $0.day == today && !$0.dropped }.sorted { $0.order < $1.order }
    }

    var openTodayTasks: [TaskItem] { todayTasks.filter { !$0.done } }

    var doneTodayCount: Int { todayTasks.filter(\.done).count }

    /// Taken van eerdere dagen die niet af zijn en niet bewust zijn laten vallen.
    var carryOver: [TaskItem] {
        data.tasks.filter { $0.day < today && !$0.done && !$0.dropped }.sorted { ($0.day, $0.order) < ($1.day, $1.order) }
    }

    func task(_ id: UUID) -> TaskItem? { data.tasks.first { $0.id == id } }

    private var nextOrder: Int { (todayTasks.map(\.order).max() ?? -1) + 1 }

    @discardableResult
    func addTask(_ title: String) -> TaskItem? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let item = TaskItem(title: t, day: today, order: nextOrder)
        data.tasks.append(item)
        return item
    }

    func setDone(_ id: UUID, _ done: Bool) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        data.tasks[i].done = done
    }

    func deleteTask(_ id: UUID) {
        data.tasks.removeAll { $0.id == id }
    }

    func moveToday(from source: IndexSet, to destination: Int) {
        var list = todayTasks
        list.move(fromOffsets: source, toOffset: destination)
        for (n, item) in list.enumerated() {
            if let i = data.tasks.firstIndex(where: { $0.id == item.id }) {
                data.tasks[i].order = n
            }
        }
    }

    func bringToToday(_ id: UUID) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        data.tasks[i].day = today
        data.tasks[i].order = nextOrder
    }

    func drop(_ id: UUID) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        data.tasks[i].dropped = true
    }

    // MARK: Gedachten

    var newThoughts: [Thought] { data.thoughts.filter { $0.status == .new } }
    var laterThoughts: [Thought] { data.thoughts.filter { $0.status == .later } }

    func park(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        data.thoughts.append(Thought(text: t))
    }

    func thoughtToToday(_ id: UUID) {
        guard let th = data.thoughts.first(where: { $0.id == id }) else { return }
        addTask(th.text)
        data.thoughts.removeAll { $0.id == id }
    }

    func thoughtLater(_ id: UUID) {
        guard let i = data.thoughts.firstIndex(where: { $0.id == id }) else { return }
        data.thoughts[i].status = .later
    }

    func removeThought(_ id: UUID) {
        data.thoughts.removeAll { $0.id == id }
    }
}
