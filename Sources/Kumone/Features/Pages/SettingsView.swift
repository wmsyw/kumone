import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AccountStore.self) private var account
    @State private var cacheSize: String = String(localized: "计算中…")
    @State private var isCheckingUpdate = false
    @State private var latestRelease: ReleaseChecker.Release?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("播放") {
                Picker("音质", selection: $settings.audioQuality) {
                    ForEach(AudioQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                Text("无损与 Hi-Res 需要黑胶 VIP，未开通时自动回落到可用音质")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("灰色歌曲解锁", isOn: $settings.enableUnblock)
                Text("无版权 / 下架歌曲自动从第三方音源（酷我、酷狗等）匹配播放")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("外观") {
                Picker("主题", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                Toggle("显示歌词翻译", isOn: $settings.showLyricsTranslation)
                #if os(macOS)
                Toggle("桌面歌词", isOn: $settings.showDesktopLyrics)
                Text("在屏幕上悬浮显示当前歌词，可拖动调整位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("存储") {
                LabeledContent("图片缓存", value: cacheSize)
                Button("清除缓存") {
                    clearCache()
                }
            }

            Section("账号") {
                if let profile = account.profile {
                    LabeledContent("当前账号", value: profile.nickname)
                    Button("退出登录", role: .destructive) {
                        Task { await AccountStore.shared.logout() }
                    }
                } else {
                    Text("未登录")
                        .foregroundStyle(.secondary)
                }
            }

            Section("关于") {
                LabeledContent("Kumone", value: appVersion)
                #if os(iOS)
                Button {
                    checkForUpdates()
                } label: {
                    HStack {
                        Text("检查更新")
                        Spacer()
                        if isCheckingUpdate {
                            ProgressView().controlSize(.small)
                        } else if let latest = latestRelease {
                            Text(String(localized: "发现新版本 \(latest.version)"))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .disabled(isCheckingUpdate)
                if let latest = latestRelease {
                    Link(destination: latest.url) {
                        Label("前往下载", systemImage: "arrow.down.circle")
                    }
                    Text("iOS 无法自动更新：下载新版 IPA 后用侧载工具重新安装即可，登录状态和设置会保留")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
                Text("网易云音乐第三方客户端 · 数据来自网易云音乐")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 440, height: 480)
        #endif
        .task { updateCacheSize() }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        Task {
            defer { isCheckingUpdate = false }
            do {
                let latest = try await ReleaseChecker.latest()
                if ReleaseChecker.isNewer(latest.version, than: ReleaseChecker.currentVersion) {
                    latestRelease = latest
                } else {
                    latestRelease = nil
                    ToastCenter.shared.show(String(localized: "已是最新版本"))
                }
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("im.missuo.Kumone/images", isDirectory: true)
    }

    private func updateCacheSize() {
        let dir = cacheDirectory
        DispatchQueue.global(qos: .utility).async {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []
            let bytes = files.reduce(0) { sum, url in
                sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            DispatchQueue.main.async {
                cacheSize = formatted
            }
        }
    }

    private func clearCache() {
        let dir = cacheDirectory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                cacheSize = String(localized: "0 字节")
                ToastCenter.shared.show(String(localized: "缓存已清除"))
            }
        }
    }
}
