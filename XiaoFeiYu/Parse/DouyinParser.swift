import Foundation

struct DouyinParser {
    static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Linux; Android 13; 2210132C Build/TKQ1.220829.002) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36",
        "Referer": "https://www.douyin.com/",
        "Accept": "application/json, text/plain, */*"
    ]

    static func parse(_ rawURL: String) async throws -> ParsedMedia {
        guard let input = URL(string: rawURL) else {
            throw NSError(domain: "Douyin", code: -1, userInfo: [NSLocalizedDescriptionKey: "链接无效"])
        }
        let final = try await HTTPClient.finalURL(input, headers: headers)
        guard let id = findAwemeId(final.absoluteString) ?? findAwemeId(rawURL) else {
            throw NSError(domain: "Douyin", code: -2, userInfo: [NSLocalizedDescriptionKey: "没有识别到抖音作品 ID"])
        }

        var comps = URLComponents(string: "https://api.amemv.com/aweme/v1/aweme/detail/")!
        comps.queryItems = [
            URLQueryItem(name: "aweme_id", value: id),
            URLQueryItem(name: "aid", value: "6383"),
            URLQueryItem(name: "device_platform", value: "web"),
            URLQueryItem(name: "version_code", value: "190500"),
            URLQueryItem(name: "version_name", value: "19.5.0")
        ]
        let json = try await HTTPClient.json(comps.url!, headers: headers)
        guard let detail = json["aweme_detail"] as? [String: Any] else {
            throw NSError(domain: "Douyin", code: -3, userInfo: [NSLocalizedDescriptionKey: "抖音返回数据为空"])
        }

        let desc = detail["desc"] as? String ?? "抖音作品"
        let author = (detail["author"] as? [String: Any])?["nickname"] as? String ?? ""

        // 图集 / 实况
        let images = detail["images"] as? [[String: Any]] ?? []
        var imageURLs: [URL] = []
        var liveURLs: [URL?] = []
        for image in images {
            guard let list = image["url_list"] as? [String],
                  let first = list.first,
                  let imageURL = URL(string: normalize(first)) else { continue }
            imageURLs.append(imageURL)

            var live: URL?
            if let video = image["video"] as? [String: Any] {
                if let play = video["play_addr"] as? [String: Any],
                   let urls = play["url_list"] as? [String],
                   let firstLive = urls.first {
                    live = URL(string: normalize(firstLive))
                } else if let playAddr = video["playAddr"] as? [[String: Any]],
                          let src = playAddr.first?["src"] as? String {
                    live = URL(string: normalize(src))
                }
            }
            liveURLs.append(live)
        }

        // 视频：bit_rate 最高档
        var videoURL: URL?
        if let video = detail["video"] as? [String: Any] {
            if let bitRates = video["bit_rate"] as? [[String: Any]],
               let best = bitRates.max(by: {
                   ($0["bit_rate"] as? Int ?? 0) < ($1["bit_rate"] as? Int ?? 0)
               }),
               let play = best["play_addr"] as? [String: Any],
               let urls = play["url_list"] as? [String],
               let first = urls.first {
                videoURL = URL(string: normalize(first))
            }
            if videoURL == nil,
               let play = video["play_addr"] as? [String: Any],
               let urls = play["url_list"] as? [String],
               let first = urls.first {
                videoURL = URL(string: normalize(first))
            }
            if videoURL == nil,
               let download = video["download_addr"] as? [String: Any],
               let urls = download["url_list"] as? [String],
               let first = urls.first {
                videoURL = URL(string: normalize(first))
            }
        }

        // 独立配乐
        var musicURL: URL?
        if let music = detail["music"] as? [String: Any],
           let play = music["play_url"] as? [String: Any] {
            if let urls = play["url_list"] as? [String], let first = urls.first {
                musicURL = URL(string: normalize(first))
            } else if let uri = play["uri"] as? String {
                musicURL = URL(string: normalize(uri))
            }
        }

        let isImage = !imageURLs.isEmpty
        let cover = (detail["video"] as? [String: Any])
            .flatMap { $0["cover"] as? [String: Any] }
            .flatMap { $0["url_list"] as? [String] }
            .flatMap { $0.first }
            .flatMap { URL(string: normalize($0)) } ?? imageURLs.first

        return ParsedMedia(
            platform: "douyin",
            type: isImage ? "image" : "video",
            title: desc,
            author: author,
            videoURL: isImage ? nil : videoURL,
            musicURL: musicURL,
            imageURLs: imageURLs,
            liveVideoURLs: liveURLs,
            coverURL: cover,
            headers: headers,
            shareURL: final.absoluteString,
            quality: "无水印"
        )
    }

    static func findAwemeId(_ url: String) -> String? {
        let patterns = [
            #"/(?:share/)?(?:video|note|slides)/(\d{6,})"#,
            #"(?:modal_id|aweme_id|item_ids)=(\d{6,})"#,
            #"(?<!\d)(\d{19})(?!\d)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: url) else { continue }
            return String(url[range])
        }
        return nil
    }

    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "/playwm/", with: "/play/")
            .replacingOccurrences(of: "watermark=1", with: "watermark=0")
    }
}
