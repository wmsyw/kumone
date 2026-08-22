import SwiftUI

#if os(macOS)
public struct KumoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var player = PlayerService.shared
    @State private var account = AccountStore.shared
    @State private var settings = SettingsManager.shared
    @State private var toasts = ToastCenter.shared

    public init() {}

    public var body: some Scene {
        WindowGroup("Kumone", id: "main") {
            MainWindow()
                .environment(player)
                .environment(account)
                .environment(settings)
                .environment(toasts)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
                .frame(minWidth: Theme.Layout.minWindowWidth,
                       minHeight: Theme.Layout.minWindowHeight)
        }
        .defaultSize(width: Theme.Layout.defaultWindowWidth,
                     height: Theme.Layout.defaultWindowHeight)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton()
            }

            CommandMenu("播放") {
                Button(player.isPlaying ? String(localized: "暂停") : String(localized: "播放")) {
                    player.togglePlayPause()
                }
                .disabled(!player.hasCurrentTrack)

                Button("下一首") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("上一首") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("随机播放") { player.toggleShuffle() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("循环模式") { player.cycleRepeatMode() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button(player.currentTrack.map { AccountStore.shared.isLiked($0.id) ? String(localized: "取消喜欢") : String(localized: "喜欢") } ?? String(localized: "喜欢")) {
                    if let track = player.currentTrack {
                        Task { await account.toggleLike(trackID: track.id) }
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(!player.hasCurrentTrack)

                Button("歌词") {
                    player.activePanel = player.activePanel == .lyrics ? nil : .lyrics
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("播放队列") {
                    player.activePanel = player.activePanel == .queue ? nil : .queue
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(account)
                .environment(settings)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Space toggles play/pause unless a text field is being edited.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let noModifiers = event.modifierFlags
                .intersection([.command, .option, .control, .shift]).isEmpty
            let editingText = NSApp.keyWindow?.firstResponder is NSText
                || NSApp.keyWindow?.firstResponder is NSTextView

            // Space: play/pause (unless typing)
            if event.keyCode == 49, noModifiers, !editingText {
                Task { @MainActor in
                    PlayerService.shared.togglePlayPause()
                }
                return nil
            }
            // Esc: close the immersive now-playing page
            if event.keyCode == 53, noModifiers, MainActor.assumeIsolated({ PlayerService.shared.showNowPlaying }) {
                Task { @MainActor in
                    PlayerService.shared.showNowPlaying = false
                }
                return nil
            }
            return event
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first { $0.identifier?.rawValue.contains("main") ?? false }?
                .makeKeyAndOrderFront(nil)
        }
        return true
    }
}
#endif
