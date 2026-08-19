import CryptoKit
import Foundation
import os.log

/// Native reimplementation of UnblockNeteaseMusic's core providers.
/// When NetEase refuses to serve a track (no copyright / delisted / paid),
/// resolve an alternative stream from third-party sources.
///
/// Provider order mirrors UnblockNeteaseMusic/server:
/// 1. pyncmd — GD Studio API, resolves by the ORIGINAL NetEase id (best fidelity)
/// 2. kuwo   — fuzzy search + duration match (±5 s), then convert_url
/// 3. kugou  — fuzzy search + duration match, tracker URL
enum UnblockService {
    private static let log = Logger(subsystem: "im.missuo.kumone", category: "unblock")
    private static let probeLimit = 8_192

    struct Resolved {
        let url: URL
        let source: String
    }

    static func resolve(_ track: Track) async -> Resolved? {
        let providers: [(name: String, source: String, candidates: () async -> [URL])] = [
            ("pyncmd", "pyncmd", { await pyncmd(track) }),
            ("kuwo", String(localized: "酷我音乐"), { await kuwo(track) }),
            ("kugou", String(localized: "酷狗音乐"), { await kugou(track) }),
        ]
        for (provider, source, fetchCandidates) in providers {
            let candidates = await fetchCandidates()
            if candidates.isEmpty {
                log.error("\(provider, privacy: .public) returned no candidates")
            }
            for (index, url) in candidates.enumerated() {
                if await probe(url, targetDurationMS: track.durationMS, provider: provider) {
                    return Resolved(url: url, source: source)
                }
                log.error("\(provider, privacy: .public) rejected candidate \(index + 1)")
            }
        }
        return nil
    }

    private static func keyword(for track: Track) -> String {
        ([track.name] + track.artists.map(\.name)).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func get(
        _ string: String, provider: String,
        userAgent: String = "Mozilla/5.0"
    ) async -> Data? {
        guard let url = URL(string: string) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode)
            else {
                log.error("\(provider, privacy: .public) request returned non-success")
                return nil
            }
            return data
        } catch {
            log.error(
                "\(provider, privacy: .public) request failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func probe(_ url: URL, targetDurationMS: Int, provider: String) async -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("bytes=0-\(probeLimit - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        do {
            let (stream, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode)
            else { return false }
            let range = contentRange(http.value(forHTTPHeaderField: "Content-Range"))
            if http.statusCode == 206 {
                guard let range, range.start == 0, range.end >= range.start,
                    range.end < Int64(probeLimit),
                    range.total.map({ $0 > range.end }) ?? true
                else { return false }
            }

            var sample: [UInt8] = []
            sample.reserveCapacity(4)
            var consumed = 0
            for try await byte in stream {
                if sample.count < 4 {
                    sample.append(byte)
                }
                consumed += 1
                if consumed == probeLimit { break }
            }
            // A 200 response may be an origin ignoring Range. Stop its transfer before
            // inspecting the bounded sample so the rest of the audio is never downloaded.
            session.invalidateAndCancel()
            guard consumed > 0 else { return false }
            let magic =
                (sample.count >= 3 && sample[0...2].elementsEqual([0x49, 0x44, 0x33]))
                || (sample.count >= 2 && sample[0] == 0xff && sample[1] & 0xe0 == 0xe0)
                || (sample.count >= 4 && sample.elementsEqual([0x66, 0x4c, 0x61, 0x43]))
            guard http.mimeType?.lowercased().hasPrefix("audio/") == true || magic else {
                return false
            }
            let total =
                range?.total
                ?? (http.statusCode == 200 && http.expectedContentLength > 0
                    ? http.expectedContentLength : nil)
            if let total, targetDurationMS > 0 {
                // AVAsset may perform uncontrolled follow-up downloads. A conservative 24 kbps
                // floor rejects Kuwo's ~11-second prompt for a normal full-length target.
                let bytesPerSecond = total / max(Int64(targetDurationMS) / 1_000, 1)
                guard bytesPerSecond >= 3_000 && bytesPerSecond <= 1_500_000 else { return false }
            }
            return true
        } catch {
            log.error(
                "\(provider, privacy: .public) probe failed: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    private static func contentRange(_ value: String?) -> (start: Int64, end: Int64, total: Int64?)?
    {
        guard let value else { return nil }
        let parts = value.lowercased().split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0] == "bytes" else { return nil }
        let rangeTotal = parts[1].split(separator: "/", maxSplits: 1)
        let bounds = rangeTotal.first?.split(separator: "-", maxSplits: 1) ?? []
        guard rangeTotal.count == 2, bounds.count == 2,
            let start = Int64(bounds[0]), let end = Int64(bounds[1])
        else { return nil }
        let total = rangeTotal[1] == "*" ? nil : Int64(rangeTotal[1])
        guard rangeTotal[1] == "*" || total != nil else { return nil }
        return (start, end, total)
    }

    // MARK: - pyncmd

    private struct PyncmdCandidate {
        let url: URL
        let bitrate: Int
    }

    private static func pyncmd(_ track: Track) async -> [URL] {
        var candidates: [PyncmdCandidate] = []
        var seen = Set<URL>()
        for requestedBitrate in [999, 320] {
            let endpoint =
                "https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id=\(track.id)&br=\(requestedBitrate)"
            guard let data = await get(endpoint, provider: "pyncmd"),
                let candidate = pyncmdCandidate(from: data)
            else { continue }
            log.info("pyncmd returned bitrate \(candidate.bitrate)")
            if seen.insert(candidate.url).inserted {
                candidates.append(candidate)
            }
        }
        return candidates.map(\.url)
    }

    private static func pyncmdCandidate(from data: Data) -> PyncmdCandidate? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let bitrate = (object["br"] as? NSNumber)?.intValue, bitrate > 0,
            let value = object["url"] as? String
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let url = URL(string: trimmed.replacingOccurrences(of: "http://", with: "https://")),
            url.host != nil
        else { return nil }
        return PyncmdCandidate(url: url, bitrate: bitrate)
    }

    // MARK: - kuwo

    private static func kuwo(_ track: Track) async -> [URL] {
        let query =
            keyword(for: track)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint =
            "http://search.kuwo.cn/r.s?correct=1&vipver=1&stype=comprehensive&encoding=utf8&rformat=json&mobi=1&show_copyright_off=1&searchapi=6&all=\(query)"
        guard let data = await get(endpoint, provider: "kuwo search"),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = object["content"] as? [[String: Any]], content.count >= 2,
            let page = content[1]["musicpage"] as? [String: Any],
            let items = page["abslist"] as? [[String: Any]]
        else { return [] }
        let songs: [(String, Int)] = items.prefix(5).compactMap {
            guard let musicRID = $0["MUSICRID"] as? String,
                let rid = musicRID.components(separatedBy: "_").last, !rid.isEmpty
            else { return nil }
            let duration =
                Int(($0["DURATION"] as? String) ?? "") ?? ($0["DURATION"] as? NSNumber)?.intValue
                ?? 0
            return (rid, duration * 1_000)
        }
        let matches = songs.filter { $0.1 > 0 && abs($0.1 - track.durationMS) < 5_000 }
        var candidates: [URL] = []
        for song in matches.isEmpty ? Array(songs.prefix(1)) : matches {
            let convert =
                "http://antiserver.kuwo.cn/anti.s?type=convert_url&format=mp3&response=url&rid=MUSIC_\(song.0)"
            guard
                let body = await get(convert, provider: "kuwo convert", userAgent: "okhttp/3.10.0"),
                let text = String(data: body, encoding: .utf8),
                let range = text.range(of: #"http[^\s$\"]+"#, options: .regularExpression),
                let url = URL(string: String(text[range])), url.host != nil
            else { continue }
            candidates.append(url)
        }
        return candidates
    }

    // MARK: - kugou

    private static func kugou(_ track: Track) async -> [URL] {
        let query =
            keyword(for: track)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint =
            "http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=\(query)&page=1&pagesize=10"
        guard let data = await get(endpoint, provider: "kugou search"),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataObject = object["data"] as? [String: Any],
            let items = dataObject["info"] as? [[String: Any]]
        else { return [] }
        let songs: [([String], String, Int)] = items.prefix(5).compactMap { item in
            let hashes = ["hash", "320hash", "sqhash"].compactMap { key -> String? in
                guard let hash = item[key] as? String,
                    hash.range(of: #"^[0-9a-fA-F]{32}$"#, options: .regularExpression) != nil
                else { return nil }
                return hash
            }
            guard !hashes.isEmpty else { return nil }
            let album =
                item["album_id"] as? String
                ?? String((item["album_id"] as? NSNumber)?.intValue ?? 0)
            return (hashes, album, ((item["duration"] as? NSNumber)?.intValue ?? 0) * 1_000)
        }
        let matches = songs.filter { $0.2 > 0 && abs($0.2 - track.durationMS) < 5_000 }
        var candidates: [URL] = []
        var attempted = Set<String>()
        for song in matches.isEmpty ? Array(songs.prefix(1)) : matches {
            for hash in song.0 where attempted.insert(hash.lowercased()).inserted {
                let key = Insecure.MD5.hash(data: Data("\(hash)kgcloudv2".utf8))
                    .map { String(format: "%02x", $0) }.joined()
                let tracker =
                    "http://trackercdn.kugou.com/i/v2/?key=\(key)&hash=\(hash)&appid=1005&pid=2&cmd=25&behavior=play&album_id=\(song.1)"
                guard let body = await get(tracker, provider: "kugou tracker"),
                    let result = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                else { continue }
                let values =
                    result["url"] as? [String] ?? (result["url"] as? String).map { [$0] } ?? []
                candidates += values.compactMap {
                    let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, let url = URL(string: value), url.host != nil else {
                        return nil
                    }
                    return url
                }
            }
        }
        return candidates
    }
}
