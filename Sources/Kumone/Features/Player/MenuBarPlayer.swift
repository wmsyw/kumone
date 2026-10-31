#if os(macOS)
import SwiftUI

struct MenuBarPlayer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CachedAsyncImage(
                    url: player.currentTrack?.album.picUrl?.resizedImageURL(128),
                    animated: false
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.name ?? String(localized: "暂无播放"))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(player.currentTrack?.name ?? String(localized: "暂无播放"))

                    Text(player.currentTrack?.artistNames ?? "Kumone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(player.currentTrack?.artistNames ?? "Kumone")

                    if player.hasCurrentTrack {
                        MenuBarPlaybackTime(clock: player.clock, duration: player.duration)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let track = player.currentTrack {
                    LikeButton(trackID: track.id, size: 14, showsActiveBackground: false)
                        .disabled(!account.isLoggedIn)
                        .accessibilityLabel(account.isLiked(track.id) ? String(localized: "取消喜欢") : String(localized: "喜欢"))
                        .help(account.isLoggedIn
                              ? (account.isLiked(track.id) ? String(localized: "取消喜欢") : String(localized: "喜欢"))
                              : String(localized: "登录后即可收藏歌曲"))
                }
            }

            Divider()

            HStack {
                Button("打开 Kumone") {
                    dismiss()
                    AppDelegate.shared?.reopenMainWindow()
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button(player.isPlaying ? String(localized: "暂停") : String(localized: "播放")) {
                        player.togglePlayPause()
                    }
                    .disabled(!player.hasCurrentTrack)

                    Button(String(localized: "上一首")) {
                        player.previous()
                    }
                    .disabled(!player.hasCurrentTrack || player.isFMMode)

                    Button(String(localized: "下一首")) {
                        player.next()
                    }
                    .disabled(!player.hasCurrentTrack)

                    Divider()

                    Button(String(localized: "设置…")) {
                        dismiss()
                        openSettings()
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    Divider()

                    Button(String(localized: "退出 Kumone")) {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("更多")
                .help("更多")
            }
            .font(.system(size: 11))
            .frame(height: 20)

            MenuBarPlayerFeedback()
        }
        .padding(10)
        .frame(width: 280)
        .onExitCommand { dismiss() }
    }
}

// MARK: - Subviews

struct MenuBarPlayerLabel: View {
    @State private var tooltip = "Kumone"

    var body: some View {
        Image(nsImage: MenuBarIcon.image)
            .accessibilityLabel("Kumone")
            .help(tooltip)
            .onReceive(PlayerService.shared.$currentTrack) { track in
                tooltip = track.map { "\($0.name) — \($0.artistNames)" } ?? "Kumone"
            }
    }
}

private struct MenuBarPlaybackTime: View {
    @ObservedObject var clock: PlaybackClock
    let duration: TimeInterval

    var body: some View {
        Text(verbatim: "\(Formatters.duration(clock.progress)) / \(Formatters.duration(duration))")
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

private struct MenuBarPlayerFeedback: View {
    @ObservedObject private var toasts = ToastCenter.shared

    var body: some View {
        if let toast = toasts.current {
            Divider()
            Text(toast.message)
                .font(.system(size: 11))
                .lineLimit(2)
                .help(toast.message)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
#endif
