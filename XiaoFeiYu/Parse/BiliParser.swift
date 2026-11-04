import Foundation
import CryptoKit

struct BiliParser {
    static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Referer": "https://www.bilibili.com/",
        "Origin": "https://www.bilibili.com"
    ]

    private static let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    ]

    static func parse(_ rawURL: String) async throws -> ParsedMedia {
        guard let input = URL(string: rawURL) else {
            throw NSError(domain: "Bili", code: -1, userInfo: [NSLocalizedDescriptionKey: "链接无效"])
        }
        let final = try await HTTPClient.finalURL(input, headers: headers)
        guard let bvid = firstMatch(#"BV[0-9A-Za-z]{10}"#, in: final.absoluteString) else {
            throw NSError(domain: "Bili", code: -2, userInfo: [NSLocalizedDescriptionKey: "没有识别到 BV 号"])
        }

        var viewURL = URLComponents(string: "https://api.bilibili.com/x/web-interface/view")!
        viewURL.queryItems = [URLQueryItem(name: "bvid", value: bvid)]
        let view = try await HTTPClient.json(viewURL.url!, headers: headers)
        guard let data = view["data"] as? [String: Any],
              let cid = data["cid"] as? Int else {
            throw NSError(domain: "Bili", code: -3, userInfo: [NSLocalizedDescriptionKey: "获取 cid 失败"])
        }

        let title = data["title"] as? String ?? "B站视频"
        let author = (data["owner"] as? [String: Any])?["name"] as? String ?? ""
        let cover = (data["pic"] as? String).flatMap { URL(string: normalize($0)) }

        let play = try await playurl(bvid: bvid, cid: cid)
        let dash = play["dash"] as? [String: Any]
        let videos = dash?["video"] as? [[String: Any]] ?? []
        let audios = dash?["audio"] as? [[String: Any]] ?? []

        if let bestVideo = pickBestVideo(videos), let videoURL = urlOf(bestVideo) {
            let audioURL = pickBestAudio(audios).flatMap { urlOf($0) }
            return ParsedMedia(
                platform: "bilibili",
                type: audioURL == nil ? "video" : "dash",
                title: title,
                author: author,
                videoURL: URL(string: videoURL),
                audioURL: audioURL.flatMap { URL(string: $0) },
                coverURL: cover,
                headers: headers,
                shareURL: final.absoluteString,
                quality: "\(bestVideo["width"] as? Int ?? 0)x\(bestVideo["height"] as? Int ?? 0)"
            )
        }

        if let durl = play["durl"] as? [[String: Any]],
           let first = durl.first,
           let u = first["url"] as? String {
            return ParsedMedia(
                platform: "bilibili", type: "video", title: title, author: author,
                videoURL: URL(string: u), coverURL: cover, headers: headers,
                shareURL: final.absoluteString, quality: "单文件"
            )
        }
        throw NSError(domain: "Bili", code: -4, userInfo: [NSLocalizedDescriptionKey: "没有解析到 B站视频地址"])
    }

    // MARK: - wbi playurl

    private static func playurl(bvid: String, cid: Int) async throws -> [String: Any] {
        var params: [String: String] = [
            "bvid": bvid,
            "cid": "\(cid)",
            "qn": "127",
            "fnver": "0",
            "fnval": "4048",
            "fourk": "1"
        ]

        if let keys = try? await wbiKeys() {
            let raw = keys.0 + keys.1
            guard raw.count >= 64 else { throw NSError(domain: "Bili", code: -7) }
            let mixin = String(
                mixinKeyEncTab.map { String(raw[raw.index(raw.startIndex, offsetBy: $0)]) }
                    .joined().prefix(32)
            )
            let wts = String(Int(Date().timeIntervalSince1970))
            params["wts"] = wts

            let sorted = params.sorted { $0.key < $1.key }
            let query = sorted.map { key, value in
                let cleaned = value.filter { !"!'()*".contains($0) }
                return "\(percent(key))=\(percent(cleaned))"
            }.joined(separator: "&")
            let wRid = md5(query + mixin)
            let url = URL(string: "https://api.bilibili.com/x/player/wbi/playurl?\(query)&w_rid=\(wRid)")!
            if let json = try? await HTTPClient.json(url, headers: headers),
               let data = json["data"] as? [String: Any] {
                return data
            }
        }

        // 回退普通 playurl
        var comps = URLComponents(string: "https://api.bilibili.com/x/player/playurl")!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        let json = try await HTTPClient.json(comps.url!, headers: headers)
        guard let data = json["data"] as? [String: Any] else {
            throw NSError(domain: "Bili", code: -5, userInfo: [NSLocalizedDescriptionKey: "playurl 返回异常"])
        }
        return data
    }

    private static func wbiKeys() async throws -> (String, String) {
        let nav = try await HTTPClient.json(
            URL(string: "https://api.bilibili.com/x/web-interface/nav")!, headers: headers
        )
        guard let data = nav["data"] as? [String: Any],
              let wbi = data["wbi_img"] as? [String: Any],
              let imgURL = wbi["img_url"] as? String,
              let subURL = wbi["sub_url"] as? String else {
            throw NSError(domain: "Bili", code: -6)
        }
        func key(_ s: String) -> String {
            (s as NSString).lastPathComponent.components(separatedBy: ".").first ?? ""
        }
        return (key(imgURL), key(subURL))
    }

    // MARK: - DASH 选择

    private static func pickBestVideo(_ list: [[String: Any]]) -> [String: Any]? {
        var best: [String: Any]?
        var bestArea = 0
        var bestRank = Int.max
        for item in list {
            let area = (item["width"] as? Int ?? 0) * (item["height"] as? Int ?? 0)
            let codec = item["codecid"] as? Int ?? 99
            let rank: Int
            switch codec {
            case 7: rank = 0
            case 12: rank = 1
            case 13: rank = 2
            default: rank = 3
            }
            if area > bestArea || (area == bestArea && rank < bestRank) {
                bestArea = area
                bestRank = rank
                best = item
            }
        }
        return best
    }

    private static func pickBestAudio(_ list: [[String: Any]]) -> [String: Any]? {
        let aac = list.filter {
            let codecs = $0["codecs"] as? String ?? ""
            let id = $0["id"] as? Int ?? 0
            return codecs.contains("mp4a") || [30216, 30232, 30280].contains(id)
        }
        let pool = aac.isEmpty ? list : aac
        return pool.max { ($0["bandwidth"] as? Int ?? 0) < ($1["bandwidth"] as? Int ?? 0) }
    }

    private static func urlOf(_ item: [String: Any]) -> String? {
        if let base = item["baseUrl"] as? String { return normalize(base) }
        if let base = item["base_url"] as? String { return normalize(base) }
        if let list = item["backupUrl"] as? [String], let first = list.first { return normalize(first) }
        return nil
    }

    // MARK: - 工具

    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "http://", with: "https://")
    }

    private static func percent(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private static func md5(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
}
