#if os(macOS)
import AppKit

/// Preserves the windows hidden by ⌘H while a nonactivating panel is in use.
/// Normal application activation (including ⌘Tab) restores that same set.
@MainActor
final class HiddenAppWindows {
    private struct Entry {
        weak var window: NSWindow?
    }

    private var entries: [Entry] = []

    nonisolated init() {}

    func capture(_ windows: [NSWindow]) {
        entries = windows.filter {
            $0.isVisible && $0.canHide && !$0.isMiniaturized
                && !$0.styleMask.contains(.nonactivatingPanel)
        }.map { Entry(window: $0) }
    }

    func suppressUnhide(for keyWindow: NSWindow?) {
        // This property is available before SwiftUI mounts the panel content.
        guard keyWindow?.styleMask.contains(.nonactivatingPanel) == true else { return }
        for entry in entries {
            entry.window?.orderOut(nil)
        }
    }

    func restore(keyWindow: NSWindow?) {
        let windows = entries.compactMap(\.window)
        entries.removeAll()
        guard !windows.isEmpty else { return }
        for window in windows.reversed() where !window.isVisible {
            window.orderFront(nil)
        }
        // Explicit Open/Settings actions may already have selected a window.
        // Otherwise return keyboard focus to the previously foremost window.
        if let keyWindow, !keyWindow.styleMask.contains(.nonactivatingPanel) {
            keyWindow.makeKeyAndOrderFront(nil)
        } else {
            windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
