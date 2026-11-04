import SwiftUI

// MARK: - Gedeelde stijl

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
    }
}

struct PillButton: View {
    let title: String
    var primary = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .foregroundStyle(primary ? Color.white : Color.primary)
                .background(primary ? AnyShapeStyle(Color.wine) : AnyShapeStyle(Color.primary.opacity(0.07)), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct Label12: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Focusbalk

struct FocusBarView: View {
    @ObservedObject var focus = FocusController.shared
    @ObservedObject var store = Store.shared

    var body: some View {
        let s = store.data.session
        let total = s.map { $0.end.timeIntervalSince($0.start) } ?? 1
        let left = s.map { max(0, $0.end.timeIntervalSince(focus.now)) } ?? 0
        let fraction = total > 0 ? left / total : 0
        let title = s.flatMap { store.task($0.taskID)?.title } ?? ""

        ZStack(alignment: .bottomLeading) {
            Capsule().fill(Color.ink.opacity(0.88))
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            GeometryReader { g in
                Capsule()
                    .fill(Color.tech)
                    .frame(width: max(0, (g.size.width - 24) * fraction), height: 2.5)
                    .offset(x: 12, y: g.size.height - 4)
                    .animation(.linear(duration: 2), value: fraction)
            }
        }
        .frame(width: 460, height: 26)
    }
}

// MARK: - Taak kiezen

struct PickerView: View {
    @ObservedObject var store = Store.shared
    @State private var selected: UUID?
    @State private var minutes: Int = UserDefaults.standard.object(forKey: "lastMinutes") as? Int ?? 90

    private let presets = [25, 45, 60, 90]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Waar ga je aan werken?")
                    .font(.system(size: 20, weight: .bold))

                let tasks = store.openTodayTasks
                if tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Je hebt nog geen open taken voor vandaag.")
                            .foregroundStyle(.secondary)
                        PillButton(title: "Dagstart openen") {
                            WindowManager.shared.closePicker()
                            WindowManager.shared.showDayStart()
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(Array(tasks.enumerated()), id: \.element.id) { i, t in
                                taskRow(t, index: i)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label12(text: "Hoe lang")
                        HStack(spacing: 6) {
                            ForEach(presets, id: \.self) { m in
                                chip("\(m) min", active: minutes == m) { minutes = m }
                            }
                            Spacer()
                            chip("−5", active: false) { minutes = max(5, minutes - 5) }
                            Text("\(minutes)").font(.system(size: 13, weight: .semibold)).monospacedDigit().frame(minWidth: 26)
                            chip("+5", active: false) { minutes = min(240, minutes + 5) }
                        }
                    }

                    HStack {
                        Text("1–9 kiest een taak · ↩ start · esc sluit")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: start) {
                            Text("Start focus")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(selected == nil ? Color.wine.opacity(0.4) : Color.wine, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                        .disabled(selected == nil)
                    }
                }
            }
        }
        .frame(width: 440, height: 420)
    }

    private func taskRow(_ t: TaskItem, index: Int) -> some View {
        let isSel = selected == t.id
        return Button { selected = t.id } label: {
            HStack(spacing: 10) {
                Text(index < 9 ? "\(index + 1)" : "")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSel ? Color.white.opacity(0.8) : Color.secondary)
                    .frame(width: 14)
                Text(t.title)
                    .font(.system(size: 14))
                    .foregroundStyle(isSel ? Color.white : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(isSel ? AnyShapeStyle(Color.wine) : AnyShapeStyle(Color.primary.opacity(0.05)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(DigitShortcut(index: index))
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundStyle(active ? Color.white : Color.primary)
                .background(active ? AnyShapeStyle(Color.ink) : AnyShapeStyle(Color.primary.opacity(0.07)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func start() {
        guard let selected else { return }
        UserDefaults.standard.set(minutes, forKey: "lastMinutes")
        FocusController.shared.start(taskID: selected, minutes: minutes)
        WindowManager.shared.closePicker()
    }
}

struct DigitShortcut: ViewModifier {
    let index: Int
    func body(content: Content) -> some View {
        if index < 9 {
            content.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
        } else {
            content
        }
    }
}

// MARK: - Gedachte parkeren

struct ParkView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color.wine)
            TextField("Wat schiet je te binnen? Parkeer het hier.", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($focused)
                .onSubmit {
                    Store.shared.park(text)
                    WindowManager.shared.closeParker()
                }
            Text("↩").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .frame(width: 460, height: 64)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true } }
    }
}

// MARK: - Einde sessie

struct EndView: View {
    let taskID: UUID
    @ObservedObject var store = Store.shared
    @State private var celebrated = false

    private static let nudges = [
        "Even opstaan en een glas water pakken?",
        "Rol je schouders 10× naar achteren.",
        "Kijk 20 seconden naar iets ver weg.",
        "Strek je armen boven je hoofd en adem diep uit.",
        "Loop even een rondje door het huis.",
        "Draai je hoofd rustig naar links en rechts.",
    ]
    @State private var nudge = EndView.nudges.randomElement()!

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                if celebrated {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Afgevinkt. Lekker bezig!")
                            .font(.system(size: 22, weight: .bold))
                        Text(doneLine).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label12(text: "Sessie klaar")
                        Text(store.task(taskID)?.title ?? "Je taak")
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(3)
                    }
                    HStack(spacing: 8) {
                        PillButton(title: "✓  Afgevinkt") {
                            store.setDone(taskID, true)
                            withAnimation(.spring(duration: 0.35)) { celebrated = true }
                        }
                        .keyboardShortcut(.defaultAction)
                        PillButton(title: "Nog 10 minuten", primary: false) {
                            FocusController.shared.start(taskID: taskID, minutes: 10)
                            WindowManager.shared.closeEnd()
                        }
                        PillButton(title: "Nog niet af", primary: false) {
                            WindowManager.shared.closeEnd()
                        }
                    }
                }

                Text(nudge)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                if !store.newThoughts.isEmpty {
                    Divider()
                    Label12(text: "Je hebt geparkeerd")
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(store.newThoughts) { th in
                                ThoughtRow(thought: th, showLater: true)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                if celebrated {
                    HStack(spacing: 8) {
                        if !store.openTodayTasks.isEmpty {
                            PillButton(title: "Volgende taak kiezen") {
                                WindowManager.shared.closeEnd(restoreFocus: false)
                                WindowManager.shared.showPicker()
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        PillButton(title: "Sluiten", primary: store.openTodayTasks.isEmpty) {
                            WindowManager.shared.closeEnd()
                        }
                    }
                }
            }
        }
        .frame(width: 440, height: 460)
    }

    private var doneLine: String {
        let n = store.doneTodayCount
        let open = store.openTodayTasks.count
        let first = n == 1 ? "Je eerste taak van vandaag is af." : "Je hebt vandaag al \(n) taken afgerond."
        return open == 0 ? first + " Alles van je lijst is klaar." : first
    }
}

struct ThoughtRow: View {
    let thought: Thought
    var showLater: Bool
    @ObservedObject var store = Store.shared

    var body: some View {
        HStack(spacing: 8) {
            Text(thought.text).font(.system(size: 13)).lineLimit(3)
            Spacer()
            small("Vandaag") { store.thoughtToToday(thought.id) }
            if showLater { small("Later") { store.thoughtLater(thought.id) } }
            small("Weg") { store.removeThought(thought.id) }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func small(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dagstart

struct DayStartView: View {
    @ObservedObject var store = Store.shared
    @State private var newTitle = ""
    @FocusState private var addFocused: Bool

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Goedemorgen"
        case 12..<18: return "Goedemiddag"
        default: return "Goedenavond"
        }
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label12(text: dateLine)
                Text(greeting).font(.system(size: 26, weight: .bold))
                Text("Waar ga je vandaag aan werken?").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 12)

            List {
                if !store.carryOver.isEmpty {
                    Section {
                        ForEach(store.carryOver) { t in
                            HStack {
                                Text(t.title)
                                Spacer()
                                Button("Meenemen") { store.bringToToday(t.id) }
                                Button("Laten vallen") { store.drop(t.id) }
                            }
                            .controlSize(.small)
                        }
                    } header: {
                        HStack {
                            Label12(text: "Nog open van eerder")
                            Spacer()
                            Button("Alles meenemen") { store.carryOver.forEach { store.bringToToday($0.id) } }
                                .controlSize(.small)
                        }
                    }
                }

                Section {
                    ForEach(store.todayTasks) { t in
                        TaskRowView(task: t)
                    }
                    .onMove { store.moveToday(from: $0, to: $1) }

                    HStack(spacing: 10) {
                        Image(systemName: "plus").foregroundStyle(.secondary).frame(width: 18)
                        TextField("Nieuwe taak, druk op ↩", text: $newTitle)
                            .textFieldStyle(.plain)
                            .focused($addFocused)
                            .onSubmit {
                                store.addTask(newTitle)
                                newTitle = ""
                                addFocused = true
                            }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label12(text: "Vandaag")
                }

                if !store.laterThoughts.isEmpty {
                    Section {
                        ForEach(store.laterThoughts) { th in
                            ThoughtRow(thought: th, showLater: false)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        Label12(text: "Geparkeerd voor later")
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("⌃⌥F  focus starten").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("⌃⌥Spatie  gedachte parkeren").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                PillButton(title: "Start focus") { WindowManager.shared.showPicker() }
                    .disabled(store.openTodayTasks.isEmpty)
                    .opacity(store.openTodayTasks.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(minWidth: 420, minHeight: 480)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { addFocused = true } }
    }
}

struct TaskRowView: View {
    let task: TaskItem
    @ObservedObject var store = Store.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button { store.setDone(task.id, !task.done) } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(task.done ? Color.wine : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 18)
            Text(task.title)
                .strikethrough(task.done)
                .foregroundStyle(task.done ? Color.secondary : Color.primary)
            Spacer()
            if hovering {
                Button { store.deleteTask(task.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Verwijderen")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
