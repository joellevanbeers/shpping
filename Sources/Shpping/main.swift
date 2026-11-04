import AppKit
import Carbon
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var dayTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // ⌃⌥F = focus starten, ⌃⌥Spatie = gedachte parkeren
        HotKeys.register(id: 1, keyCode: kVK_ANSI_F, modifiers: controlKey | optionKey) {
            WindowManager.shared.showPicker()
        }
        HotKeys.register(id: 2, keyCode: kVK_Space, modifiers: controlKey | optionKey) {
            WindowManager.shared.showParker()
        }

        FocusController.shared.resumeIfNeeded()
        checkNewDay()

        // Elke minuut: icoon bijwerken en kijken of er een nieuwe dag is begonnen.
        dayTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                (NSApp.delegate as? AppDelegate)?.updateIcon()
                (NSApp.delegate as? AppDelegate)?.checkNewDay()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in (NSApp.delegate as? AppDelegate)?.checkNewDay() }
        }
    }

    /// Opent de dagstart één keer per dag, vanaf 5:00.
    func checkNewDay() {
        let store = Store.shared
        let hour = Calendar.current.component(.hour, from: Date())
        if store.data.lastDayStart != store.today && hour >= 5 && !FocusController.shared.isRunning {
            WindowManager.shared.showDayStart()
        }
    }

    func updateIcon() {
        let running = FocusController.shared.isRunning
        let img = NSImage(systemSymbolName: running ? "shippingbox.fill" : "shippingbox", accessibilityDescription: "Shpping")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let focus = FocusController.shared

        if focus.isRunning, let t = focus.currentTask {
            let now = NSMenuItem(title: "Bezig met: \(t.title)", action: nil, keyEquivalent: "")
            now.isEnabled = false
            menu.addItem(now)
            let left = NSMenuItem(title: "Nog \(focus.minutesLeft) min", action: nil, keyEquivalent: "")
            left.isEnabled = false
            menu.addItem(left)
            menu.addItem(item("Sessie afronden", #selector(stopFocus)))
            menu.addItem(item("Andere taak kiezen…", #selector(openPicker)))
        } else {
            menu.addItem(item("Focus starten…   ⌃⌥F", #selector(openPicker)))
        }
        menu.addItem(item("Gedachte parkeren…   ⌃⌥Spatie", #selector(openParker)))
        menu.addItem(item("Dagstart…", #selector(openDayStart)))
        menu.addItem(.separator())

        let login = item("Openen bij inloggen", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Notificaties uitzetten instellen…", #selector(showFocusHelp)))
        menu.addItem(.separator())
        menu.addItem(item("Stop Shpping", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openPicker() { WindowManager.shared.showPicker() }
    @objc private func openParker() { WindowManager.shared.showParker() }
    @objc private func openDayStart() { WindowManager.shared.showDayStart() }
    @objc private func stopFocus() { FocusController.shared.stop(); updateIcon() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let a = NSAlert()
            a.messageText = "Lukt niet"
            a.informativeText = "Zet Shpping in de map Apps (Programma's) en probeer het opnieuw.\n\n\(error.localizedDescription)"
            NSApp.activate(ignoringOtherApps: true)
            a.runModal()
        }
    }

    @objc private func showFocusHelp() {
        let ok = FocusController.shortcutsInstalled()
        let a = NSAlert()
        a.messageText = ok ? "Notificaties uitzetten staat aan ✓" : "Notificaties uitzetten instellen"
        a.informativeText = ok
            ? "Shpping zet je focusmodus aan bij de start van een sessie en weer uit aan het eind."
            : """
              Maak in de app Opdrachten twee opdrachten:

              1. "\(FocusController.shortcutOn)"
                 actie: Stel focus in → Niet storen → Aan

              2. "\(FocusController.shortcutOff)"
                 actie: Stel focus in → Niet storen → Uit

              De namen moeten precies zo zijn. Daarna doet Shpping de rest.
              """
        if !ok { a.addButton(withTitle: "Open Opdrachten"); a.addButton(withTitle: "Later") }
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn && !ok {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Lopende sessie blijft bewaard en wordt hervat bij de volgende start.
    }
}

// Icoon in de menubalk bijwerken zodra een sessie start of stopt.
extension FocusController {
    func refreshMenuIcon() { (NSApp.delegate as? AppDelegate)?.updateIcon() }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
