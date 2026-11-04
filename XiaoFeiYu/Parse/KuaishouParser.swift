import Foundation

struct KuaishouParser {
    static let headers: [String: String] = [
        "User-Agent": HTTPClient.mobileUA,
        "Referer": "https://www.kuaishou.com/",
        "Content-Type": "application/json"
    ]

    static func parse(_ rawURL: String) async throws -> ParsedMedia {
        guard let input = URL(string: rawURL) else {
            throw NSError(domain: "KS", code: -1, userInfo: [NSLocalizedDescriptionKey: "链接无效"])
        }
        let final = try await HTTPClient.finalURL(input, headers: headers)
        guard let id = photoId(final.absoluteString) else {
            throw NSError(domain: "KS", code: -2, userInfo: [NSLocalizedDescriptionKey: "没有识别到快手作品 ID"])
        }

        let body: [String: Any] = [
            "photoId": id,
            "kpn": "KUAISHOU",
            "subBiz": "PHOTO"
        ]
        let json = try await HTTPClient.postJSON(
            URL(string: "https://m.gifshow.com/rest/wd/ugH5App/photo/simple/info")!,
            body: body,
            headers: headers
        )

        let photo = json["photo"] as? [String: Any] ?? [:]
        let caption = photo["caption"] as? String ?? "快手作品"
        let author = photo["userName"] as? String ?? ""

        var videoURL: URL?
        if let mv = photo["mainMvUrls"] as? [[String: Any]],
           let first = mv.first,
           let url = first["url"] as? String {
            videoURL = URL(string: url)
        }

        var images: [URL] = []
        if let atlas = json["atlas"] as? [String: Any],
           let cdns = atlas["cdnList"] as? [[String: Any]],
           let paths = atlas["list"] as? [String],
           let cdn = cdns.first?["cdn"] as? String, !cdn.isEmpty {
            images = paths.compactMap { URL(string: "https://\(cdn)\($0)") }
        }

        return ParsedMedia(
            platform: "kuaishou",
            type: images.isEmpty ? "video" : "image",
            title: caption,
            author: author,
            videoURL: images.isEmpty ? videoURL : nil,
            imageURLs: images,
            coverURL: images.first,
            headers: headers,
            shareURL: final.absoluteString,
            quality: "无水印"
        )
    }

    private static func photoId(_ url: String) -> String? {
        let patterns = [#"/short-video/([A-Za-z0-9]+)"#, #"/photo/([A-Za-z0-9]+)"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
                  let range = Range(match.range(at: 1), in: url) else { continue }
            return String(url[range])
        }
        return nil
    }
}
