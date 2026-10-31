#if os(macOS)
import Foundation
import Darwin
import MLX
import Testing
@testable import StemKit

@Suite(.serialized)
struct StemMetalResourcesTests {
    @Test func anUnbundledBuildDoesNotInstallResources() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let resources = StemMetalResources(archive: nil, directory: directory, version: nil)
        try await resources.load()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func invalidArchiveDoesNotBecomeAnInstalledFramework() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archive = directory.appendingPathComponent("broken.zip")
        try Data("not an archive".utf8).write(to: archive)
        let interrupted = directory.appendingPathComponent("\(UUID().uuidString).partial")
        try FileManager.default.createDirectory(at: interrupted, withIntermediateDirectories: true)
        try Data("interrupted extraction".utf8).write(to: interrupted.appendingPathComponent("payload"))
        let resources = StemMetalResources(archive: archive, directory: directory, version: "fixture")
        await #expect(throws: StemMetalResources.ResourceError.self) { try await resources.load() }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("KumoneStemResources.framework").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["broken.zip"])
    }

    @Test func aCachedFrameworkWithTheWrongIdentityIsReinstalled() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let contents = directory.appendingPathComponent("KumoneStemResources.framework/Resources")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "wrong.identity", "KumoneResourceVersion": "fixture"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data().write(to: contents.appendingPathComponent("default.metallib"))
        try #require(Bundle(url: contents.deletingLastPathComponent())?.bundleIdentifier == "wrong.identity")
        let archive = directory.appendingPathComponent("broken.zip")
        try Data("not an archive".utf8).write(to: archive)
        let resources = StemMetalResources(archive: archive, directory: directory, version: "fixture")
        // Reinstallation must reach extraction, rather than trying to load the unrelated cached bundle.
        await #expect(throws: StemMetalResources.ResourceError.self) { try await resources.load() }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["KUMONE_STEM_RESOURCE_ARCHIVE"] != nil))
    func compressedResourcesLoadOnceAndSupportMetalComputation() async throws {
        let original = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["KUMONE_STEM_RESOURCE_ARCHIVE"]))
        let version = try #require(ProcessInfo.processInfo.environment["KUMONE_STEM_RESOURCE_VERSION"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try Self.ditto(["-x", "-k", original.path, source.path])
        let executable = source.appendingPathComponent("KumoneStemResources.framework/Versions/A/KumoneStemResources")
        let quarantine = Array("0083;69000000;Safari;DDE0C101-4314-4A9D-A915-430B0B273273".utf8)
        let markedExecutable = quarantine.withUnsafeBytes {
            setxattr(executable.path, "com.apple.quarantine", $0.baseAddress, $0.count, 0, 0)
        }
        #expect(markedExecutable == 0)
        let archive = root.appendingPathComponent("quarantined.zip")
        try Self.ditto(["-c", "-k", "--keepParent", source.appendingPathComponent("KumoneStemResources.framework").path, archive.path])
        let markedArchive = quarantine.withUnsafeBytes {
            setxattr(archive.path, "com.apple.quarantine", $0.baseAddress, $0.count, 0, 0)
        }
        #expect(markedArchive == 0)
        let directory = root.appendingPathComponent("Metal")
        let resources = StemMetalResources(archive: archive, directory: directory, version: version)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        async let first: Void = resources.load()
        async let second: Void = resources.load()
        _ = try await (first, second)
        let framework = directory.appendingPathComponent("KumoneStemResources.framework")
        let installedExecutable = framework.appendingPathComponent("Versions/A/KumoneStemResources")
        let quarantineSize = getxattr(installedExecutable.path, "com.apple.quarantine", nil, 0, 0, 0)
        let quarantineError = errno
        #expect(quarantineSize == -1)
        #expect(quarantineError == ENOATTR)
        let installed = try framework.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        #expect(Bundle.allFrameworks.contains { $0.bundleIdentifier == "mlx-swift_Cmlx" && $0.isLoaded })
        let cached = StemMetalResources(archive: archive, directory: directory, version: version)
        try await cached.load()
        #expect(try framework.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == installed)
        let replacementDirectory = root.appendingPathComponent("Replacement")
        let replacement = replacementDirectory.appendingPathComponent("KumoneStemResources.framework")
        let invalidResources = replacement.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: invalidResources, withIntermediateDirectories: true)
        let invalidInfo = ["CFBundleIdentifier": "wrong.identity", "KumoneResourceVersion": version]
        try PropertyListSerialization.data(fromPropertyList: invalidInfo, format: .xml, options: 0)
            .write(to: invalidResources.appendingPathComponent("Info.plist"))
        try Data().write(to: invalidResources.appendingPathComponent("default.metallib"))
        try await StemMetalResources(archive: archive, directory: replacementDirectory, version: version).load()
        let replacedBundle = try #require(Bundle(url: replacement))
        #expect(replacedBundle.bundleIdentifier == "mlx-swift_Cmlx")
        #expect(replacedBundle.isLoaded)
        Device.withDefaultDevice(.gpu) {
            let input = MLXArray([Float(1), 2, 3])
            let output = input + input
            eval(output)
            #expect(output.asArray(Float.self) == [2, 4, 6])
        }
    }

    private static func ditto(_ arguments: [String]) throws {
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        command.arguments = arguments
        try command.run()
        command.waitUntilExit()
        #expect(command.terminationStatus == 0)
    }
}
#endif
