#if os(iOS)
import SwiftUI
import UIKit

/// iOS in-app updater, Dopamine-style. Detects a newer GitHub release,
/// downloads the IPA with a circular progress ring, then hands it to
/// TrollStore for installation via `apple-magnifier://install?url=`.
///
/// Auto-install requires **TrollStore** (which registers the
/// `apple-magnifier` scheme and installs unsigned IPAs system-wide). On a
/// plain AltStore/SideStore sideload there is no such install primitive, so
/// the updater falls back to opening the release page for a manual reinstall.
@MainActor
@Observable
final class IOSUpdater: NSObject {
    static let shared = IOSUpdater()

    enum Phase {
        case idle
        case checking
        case upToDate
        case available(ReleaseChecker.Release)
        case downloading(Double)        // 0…1
        case readyToInstall(URL)        // local .ipa (non-TrollStore)
        case handedOff                  // passed to TrollStore
        case failed(String)
    }

    var phase: Phase = .idle
    var showSheet = false

    private var downloadTask: URLSessionDownloadTask?
    private var progressContinuation: CheckedContinuation<URL, Error>?

    /// Whether TrollStore is present and claims the install scheme.
    /// `canOpenURL("apple-magnifier://")` alone is unreliable — the system
    /// Magnifier claims that scheme too — so mirror Dopamine and confirm
    /// the TrollStore bundle claims it (via the LSApplicationProxy SPI).
    static var isTrollStoreAvailable: Bool {
        guard let cls = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
              cls.responds(to: NSSelectorFromString("applicationProxyForIdentifier:"))
        else { return false }
        let proxy = cls.perform(NSSelectorFromString("applicationProxyForIdentifier:"),
                                with: "com.opa334.TrollStore")?.takeUnretainedValue()
        guard let proxy = proxy as? NSObject,
              let schemes = proxy.value(forKey: "claimedURLSchemes") as? [String]
        else { return false }
        return schemes.contains("apple-magnifier")
    }

    func check(interactive: Bool) {
        phase = .checking
        if interactive { showSheet = true }
        Task {
            do {
                let latest = try await ReleaseChecker.latest()
                if ReleaseChecker.isNewer(latest.version, than: ReleaseChecker.currentVersion) {
                    phase = .available(latest)
                    showSheet = true
                } else {
                    phase = .upToDate
                    if !interactive { showSheet = false }
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func download(_ release: ReleaseChecker.Release) {
        guard let ipaURL = release.ipaURL else {
            openReleasePage(release)
            return
        }
        // TrollStore path (Dopamine's Path B): don't pre-download — hand the
        // remote asset URL to TrollStore, which fetches and installs it with
        // its own privileges, then relaunches.
        if Self.isTrollStoreAvailable {
            let scheme = "apple-magnifier://install?url=\(ipaURL.absoluteString)"
            if let url = URL(string: scheme) {
                UIApplication.shared.open(url)
                phase = .handedOff
                return
            }
        }
        // No TrollStore: still show the progress ring while downloading, then
        // present a share/save sheet so the user can pass the IPA to a signer.
        phase = .downloading(0)
        Task {
            do {
                let localURL = try await downloadIPA(from: ipaURL)
                phase = .readyToInstall(localURL)
                presentShareSheet(for: localURL)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func openReleasePage(_ release: ReleaseChecker.Release) {
        UIApplication.shared.open(release.url)
    }

    // MARK: - Download (non-TrollStore fallback)

    private func downloadIPA(from url: URL) async throws -> URL {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return try await withCheckedThrowingContinuation { continuation in
            progressContinuation = continuation
            let task = session.downloadTask(with: url)
            downloadTask = task
            task.resume()
        }
    }

    private func presentShareSheet(for url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        let picker = UIDocumentPickerViewController(forExporting: [url])
        root.present(picker, animated: true)
    }
}

extension IOSUpdater: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            if case .downloading = self.phase { self.phase = .downloading(fraction) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Move to a stable .ipa path before the temp file is reaped.
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kumone-update.ipa")
        try? FileManager.default.removeItem(at: dest)
        let moved = (try? { try FileManager.default.moveItem(at: location, to: dest); return true }()) ?? false
        let result = moved ? dest : location
        Task { @MainActor in
            self.progressContinuation?.resume(returning: result)
            self.progressContinuation = nil
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor in
            self.progressContinuation?.resume(throwing: error)
            self.progressContinuation = nil
        }
    }
}

// MARK: - UI

struct IOSUpdaterSheet: View {
    @Bindable var updater = IOSUpdater.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            switch updater.phase {
            case .checking:
                ProgressView()
                Text("正在检查更新…").foregroundStyle(.secondary)

            case .upToDate:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(.green)
                Text("已是最新版本").font(.headline)
                doneButton

            case .available(let release):
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(Theme.accent)
                VStack(spacing: 4) {
                    Text("发现新版本 \(release.version)").font(.headline)
                    Text("当前版本 \(ReleaseChecker.currentVersion)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if IOSUpdater.isTrollStoreAvailable {
                    Text("将下载并通过 TrollStore 自动安装")
                        .font(.caption).foregroundStyle(.secondary)
                    primaryButton("下载并安装") { updater.download(release) }
                } else {
                    Text("未检测到 TrollStore，将打开发布页手动侧载")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    primaryButton("前往下载") { updater.openReleasePage(release); dismiss() }
                }
                laterButton

            case .downloading(let progress):
                ProgressRing(progress: progress)
                Text("正在下载 \(Int(progress * 100))%")
                    .font(.headline).monospacedDigit()

            case .readyToInstall:
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("已下载，请用侧载工具安装").font(.headline)
                    .multilineTextAlignment(.center)
                doneButton

            case .handedOff:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(.green)
                Text("已移交 TrollStore 安装").font(.headline)
                Text("请在 TrollStore 中完成安装").font(.caption).foregroundStyle(.secondary)
                doneButton

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40)).foregroundStyle(.orange)
                Text(message).font(.subheadline)
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                doneButton

            case .idle:
                EmptyView()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(320)])
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Theme.accentGradient, in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private var laterButton: some View {
        Button("稍后") { dismiss() }
            .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(.secondary)
    }

    private var doneButton: some View {
        Button("完成") { dismiss() }.buttonStyle(.pressable)
    }
}

/// Circular download-progress ring.
struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accentGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
            Text("\(Int(progress * 100))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 96, height: 96)
    }
}
#endif
