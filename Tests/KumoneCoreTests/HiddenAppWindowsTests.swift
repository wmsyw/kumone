#if os(macOS)
import AppKit
import Testing
@testable import KumoneCore

@MainActor
private final class RestorationWindow: NSWindow {
    var onScreen = true
    var focused = false
    override var isVisible: Bool { onScreen }
    override func orderOut(_ sender: Any?) { onScreen = false }
    override func orderFront(_ sender: Any?) { onScreen = true }
    override func makeKeyAndOrderFront(_ sender: Any?) {
        onScreen = true
        focused = true
    }
}

@Suite @MainActor
struct HiddenAppWindowsTests {
    private func window() -> RestorationWindow {
        _ = NSApplication.shared
        let window = RestorationWindow(contentRect: .zero,
                                       styleMask: [.titled],
                                       backing: .buffered, defer: true)
        window.canHide = true
        return window
    }

    private func panel() -> NSPanel {
        NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel],
                backing: .buffered, defer: true)
    }

    @Test func firstPanelOpenPreservesMainAndSettingsForApplicationSwitching() {
        let main = window()
        let settings = window()
        let panel = panel()
        let restoration = HiddenAppWindows()
        restoration.capture([settings, main, panel])
        restoration.suppressUnhide(for: panel)
        #expect(!main.isVisible && !settings.isVisible)
        #expect(!panel.isVisible)

        restoration.restore(keyWindow: nil)
        #expect(main.isVisible && settings.isVisible)
        #expect(settings.focused)
    }

    @Test func dismissedAndRecreatedPanelsNeedNoViewRegistration() {
        let main = window()
        let restoration = HiddenAppWindows()
        restoration.capture([main])
        restoration.suppressUnhide(for: panel())
        restoration.suppressUnhide(for: panel())
        #expect(!main.isVisible)
        restoration.restore(keyWindow: nil)
        #expect(main.isVisible)
    }

    @Test func applicationActivationRestoresWindowsWhenPanelStillHasKeyFocus() {
        let main = window()
        let panel = panel()
        let restoration = HiddenAppWindows()
        restoration.capture([main])
        restoration.suppressUnhide(for: panel)
        #expect(!main.isVisible)

        restoration.restore(keyWindow: panel)
        #expect(main.isVisible && main.focused)
    }

    @Test func closedWindowsStayClosedAndExplicitSettingsKeepFocus() {
        let main = window()
        let closed = window()
        closed.onScreen = false
        let settings = window()
        let restoration = HiddenAppWindows()
        restoration.capture([main, closed])
        restoration.suppressUnhide(for: panel())
        restoration.restore(keyWindow: settings)
        #expect(main.isVisible)
        #expect(!closed.isVisible)
        #expect(settings.focused && !main.focused)

        main.onScreen = false
        restoration.restore(keyWindow: nil)
        #expect(!main.isVisible)
    }

    @Test func ordinaryWindowUnhideIsLeftToAppKit() {
        let main = window()
        let restoration = HiddenAppWindows()
        restoration.capture([main])
        restoration.suppressUnhide(for: main)
        #expect(main.isVisible)
        restoration.suppressUnhide(for: nil)
        #expect(main.isVisible)
    }
}
#endif
