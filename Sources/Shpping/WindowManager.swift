import AppKit
import SwiftUI

/// Paneel dat toetsenbordinvoer mag ontvangen, zonder titelbalk. Esc sluit het.
final class KeyPanel: NSPanel {
    var closeOnResign = true

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        WindowManager.shared.dismiss(self)
    }

    override func resignKey() {
        super.resignKey()
        if closeOnResign && isVisible { WindowManager.shared.dismiss(self, restoreFocus: false) }
    }
}

/// De dunne focusbalk bovenin het scherm. Klikken gaan er dwars doorheen.
final class BarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
    override var canBecomeKey: Bool { false }
}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var bar: BarPanel?
    private var picker: KeyPanel?
    private var parker: KeyPanel?
    private var end: KeyPanel?
    private var dayStart: NSWindow?

    /// De app die voorop stond voordat we een paneel openden, zodat we daar weer naar terug kunnen.
    private var previousApp: NSRunningApplication?

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
    }

    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private var menuBarScreen: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    private func placeTop(_ w: NSWindow, offset: CGFloat = 120) {
        let s = menuBarScreen
        let size = w.frame.size
        w.setFrameOrigin(NSPoint(x: s.frame.midX - size.width / 2,
                                 y: s.visibleFrame.maxY - size.height - offset))
    }

    // MARK: Focusbalk

    func showBar() {
        if bar == nil {
            let p = BarPanel()
            p.contentView = NSHostingView(rootView: FocusBarView())
            bar = p
        }
        guard let bar else { return }
        let s = menuBarScreen
        let size = NSSize(width: 520, height: 26)
        bar.setFrame(NSRect(x: s.frame.midX - size.width / 2,
                            y: s.visibleFrame.maxY - size.height - 4,
                            width: size.width, height: size.height), display: true)
        bar.orderFrontRegardless()
    }

    func hideBar() { bar?.orderOut(nil) }

    // MARK: Taak kiezen

    func showPicker() {
        rememberFrontApp()
        dismissAll(except: nil)
        let p = KeyPanel(size: NSSize(width: 440, height: 460))
        p.contentView = NSHostingView(rootView: PickerView())
        picker = p
        placeTop(p)
        activate()
        p.makeKeyAndOrderFront(nil)
    }

    // MARK: Gedachte parkeren

    func showParker() {
        rememberFrontApp()
        parker?.orderOut(nil)
        let p = KeyPanel(size: NSSize(width: 460, height: 64))
        p.contentView = NSHostingView(rootView: ParkView())
        parker = p
        placeTop(p, offset: 60)
        activate()
        p.makeKeyAndOrderFront(nil)
    }

    // MARK: Einde sessie

    func showEnd(taskIDs: [UUID]) {
        rememberFrontApp()
        dismissAll(except: nil)
        let p = KeyPanel(size: NSSize(width: 440, height: 480))
        p.closeOnResign = false
        p.contentView = NSHostingView(rootView: EndView(taskIDs: taskIDs))
        end = p
        placeTop(p)
        activate()
        p.makeKeyAndOrderFront(nil)
    }

    // MARK: Dagstart

    func showDayStart() {
        Store.shared.data.lastDayStart = Store.shared.today
        if dayStart == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 620),
                             styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: DayStartView())
            w.center()
            dayStart = w
        }
        activate()
        dayStart?.makeKeyAndOrderFront(nil)
    }

    // MARK: Sluiten

    func dismiss(_ w: NSWindow, restoreFocus: Bool = true) {
        w.orderOut(nil)
        if w === picker { picker = nil }
        if w === parker { parker = nil }
        if w === end { end = nil }
        if restoreFocus { returnToPreviousApp() }
    }

    func closePicker() { if let picker { dismiss(picker) } }
    func closeParker() { if let parker { dismiss(parker) } }
    func closeEnd(restoreFocus: Bool = true) { if let end { dismiss(end, restoreFocus: restoreFocus) } }

    private func dismissAll(except: NSWindow?) {
        for w in [picker, parker, end].compactMap({ $0 }) where w !== except {
            dismiss(w, restoreFocus: false)
        }
    }

    private func returnToPreviousApp() {
        // Alleen terugspringen als er geen ander Shpping-venster open staat dat aandacht wil.
        if dayStart?.isKeyWindow == true { return }
        previousApp?.activate()
    }
}
