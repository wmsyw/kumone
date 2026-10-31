import Foundation

/// The process's one separator, loaded on demand and kept warm.
///
/// The app's AutoMix pre-render needs exactly this (as did the offline
/// `audition` console, now in the branch history) — three things: load the 64 MiB
/// checkpoint at most once, call the `async` separator from a synchronous pull
/// loop, and ask "could this machine separate at all?" without triggering a
/// download or a Metal failure.
public final class ResidentStemSeparator: @unchecked Sendable {

    public static let shared = ResidentStemSeparator()

    private let lock = NSLock()
    private var separator: StemSeparator?
    private var fourStem: StemSeparator?

    private init() {}

    /// Is the four-stem checkpoint on this machine?
    ///
    /// Separate from ``isRunnable()`` and deliberately independent of it: the
    /// vocals model downloads itself and the four-stem one does not
    /// (`Scripts/fetch-4stem-checkpoint.sh`), so "has a separator" and "has a
    /// four-lane separator" are genuinely different questions with different
    /// answers on most installs.
    public static func hasFourStem(modelStore: ModelStore = ModelStore()) -> Bool {
        isRunnable(modelStore: modelStore, descriptor: .bsRoformerFourStem)
    }

    /// Separate one window into all four lanes, blocking until it is done.
    ///
    /// The `other` lane is the model's own; the caller is what decides whether
    /// to keep it or re-derive it as a residual — see
    /// ``SeparatedStems/partition()``, which is what this returns.
    public func stems(samples: [[Float]], sampleRate: Double) throws -> [StemLane: [[Float]]] {
        let separator = try residentFourStem()
        return try runBlocking {
            try await separator.separate(samples: samples, sampleRate: sampleRate)
        }.partition()
    }

    public func residentFourStem() throws -> StemSeparator {
        lock.lock()
        let existing = fourStem
        lock.unlock()
        if let existing { return existing }

        let prepared = try runBlocking {
            try await StemSeparator.prepare(descriptor: .bsRoformerFourStem)
        }
        lock.lock()
        if let existing = fourStem {
            lock.unlock()
            return existing
        }
        fourStem = prepared
        lock.unlock()
        return prepared
    }

    /// Are the model and kernel resources supplied on this Apple silicon machine?
    /// Does not download, extract, or initialize MLX. `prepare()` installs the
    /// bundled framework on demand and reports extraction or loading failures.
    public static func isRunnable(modelStore: ModelStore = ModelStore(),
                                  descriptor: ModelDescriptor = .zfturboVocalsV1) -> Bool {
        #if arch(arm64)
        FileManager.default.fileExists(atPath: modelStore.localURL(for: descriptor).path)
            && (StemMetalResources.shared.archive != nil || metallibURL() != nil)
        #else
        // The release app is universal, but MLX's Metal backend is Apple
        // silicon only: the x86_64 slice compiles and must never run it.
        false
        #endif
    }

    /// Uncompressed kernels for bare SwiftPM/CLI builds, cached on first access.
    /// Packaged apps use `StemMetalResources` instead; this lookup does not
    /// discover the framework's `default.metallib` installed later on first use.
    public static func metallibURL() -> URL? { cachedMetallibURL }

    private static let cachedMetallibURL: URL? = findMetallib()

    private static func findMetallib() -> URL? {
        var candidates: [URL] = []
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(executable.appendingPathComponent("mlx.metallib"))
        }
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let url = bundle.url(forResource: "mlx", withExtension: "metallib") {
                candidates.append(url)
            }
        }
        // An Xcode-built SwiftPM package ships it inside its own resource
        // bundle, which is not loaded and so not in `allBundles`.
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("mlx.metallib"))
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: resources, includingPropertiesForKeys: nil)) ?? []
            for bundle in contents where bundle.pathExtension == "bundle" {
                candidates.append(bundle.appendingPathComponent("mlx.metallib"))
                candidates.append(bundle.appendingPathComponent("Contents/Resources/mlx.metallib"))
            }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Separate one window, blocking until it is done. Never call this on the
    /// main thread: it is seconds of Metal work.
    public func vocals(samples: [[Float]], sampleRate: Double) throws -> [[Float]] {
        let separator = try resident()
        return try runBlocking {
            try await separator.separate(samples: samples, sampleRate: sampleRate)
        }.vocals
    }

    public func resident() throws -> StemSeparator {
        lock.lock()
        let existing = separator
        lock.unlock()
        if let existing { return existing }

        let prepared = try runBlocking { try await StemSeparator.prepare() }
        lock.lock()
        // Two callers racing here is harmless — the loser's copy is dropped.
        if let existing = separator {
            lock.unlock()
            return existing
        }
        separator = prepared
        lock.unlock()
        return prepared
    }

    /// `async` model, synchronous callers. Bridging here rather than making the
    /// renderers async keeps the offline graph exactly the shape the live
    /// engine's is.
    private func runBlocking<T: Sendable>(
        _ body: @escaping @Sendable () async throws -> T
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var outcome: Result<T, Error>?
        Task.detached(priority: .userInitiated) {
            do { outcome = .success(try await body()) } catch { outcome = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        switch outcome! {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}
