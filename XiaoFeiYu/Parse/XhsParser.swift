import Foundation

struct XhsParser {
    static let headers: [String: String] = [
        "User-Agent": HTTPClient.mobileUA,
        "Referer": "https://www.xiaohongshu.com/"
    ]

    static func parse(_ rawURL: String) async throws -> ParsedMedia {
        guard let input = URL(string: rawURL) else {
            throw NSError(domain: "XHS", code: -1, userInfo: [NSLocalizedDescriptionKey: "链接无效"])
        }
        let final = try await HTTPClient.finalURL(input, headers: headers)
        let (html, _) = try await HTTPClient.text(final, headers: headers)

        guard let state = extractState(html),
              let root = try? JSONSerialization.jsonObject(with: Data(state.utf8)) as? [String: Any],
              let note = findNote(root) else {
            throw NSError(domain: "XHS", code: -2, userInfo: [NSLocalizedDescriptionKey: "小红书数据解析失败"])
        }

        let title = note["title"] as? String ?? (note["desc"] as? String) ?? "小红书笔记"
        let author = ((note["user"] as? [String: Any])?["nickName"] as? String)
            ?? ((note["user"] as? [String: Any])?["nickname"] as? String) ?? ""

        var images: [URL] = []
        var lives: [URL?] = []
        if let list = note["imageList"] as? [[String: Any]] {
            for image in list {
                let raw = image["url"] as? String ?? image["urlDefault"] as? String ?? ""
                guard !raw.isEmpty, let imageURL = cleanImage(raw, fileId: image["fileId"] as? String) else { continue }
                images.append(imageURL)
                lives.append(liveVideo(image))
            }
        }

        var videoURL: URL?
        if let video = note["video"] as? [String: Any],
           let consumer = video["consumer"] as? [String: Any],
           let key = consumer["originVideoKey"] as? String {
            videoURL = URL(string: "https://sns-video-bd.xhscdn.com/\(key)")
        }

        return ParsedMedia(
            platform: "xhs",
            type: !images.isEmpty ? "image" : "video",
            title: title,
            author: author,
            videoURL: images.isEmpty ? videoURL : nil,
            imageURLs: images,
            liveVideoURLs: lives,
            coverURL: images.first,
            headers: headers,
            shareURL: final.absoluteString,
            quality: "原图"
        )
    }

    private static func extractState(_ html: String) -> String? {
        let pattern = #"window\.__INITIAL_STATE__\s*=\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let start = Range(match.range, in: html) else { return nil }
        let rest = html[start.upperBound...]
        guard let end = rest.range(of: "</script>") else { return nil }
        return String(rest[..<end.lowerBound])
            .replacingOccurrences(of: ":undefined", with: ":null")
            .replacingOccurrences(of: "[undefined", with: "[null")
    }

    private static func findNote(_ root: [String: Any]) -> [String: Any]? {
        if let noteData = root["noteData"] as? [String: Any],
           let data = noteData["data"] as? [String: Any],
           let note = data["noteData"] as? [String: Any] {
            return note
        }
        if let note = root["note"] as? [String: Any],
           let detail = note["noteDetail"] as? [String: Any] {
            return detail
        }
        return nil
    }

    private static func cleanImage(_ raw: String, fileId: String?) -> URL? {
        let base = raw.components(separatedBy: "?").first?
            .components(separatedBy: "!").first ?? raw
        let key: String?
        if let range = base.range(of: "/notes_") {
            key = String(base[range.lowerBound...].dropFirst())
        } else {
            key = fileId
        }
        guard let key, !key.isEmpty else { return nil }
        return URL(string: "https://sns-img-qc.xhscdn.com/\(key)?imageView2/2/w/1080/format/jpg")
    }

    private static func liveVideo(_ image: [String: Any]) -> URL? {
        guard let stream = image["stream"] as? [String: Any] else { return nil }
        for codec in ["h264", "h265", "av1"] {
            guard let list = stream[codec] as? [[String: Any]],
                  let first = list.first else { continue }
            if let url = first["masterUrl"] as? String,
               let live = URL(string: url.replacingOccurrences(of: "http://", with: "https://")) {
                return live
            }
        }
        return nil
    }
}
