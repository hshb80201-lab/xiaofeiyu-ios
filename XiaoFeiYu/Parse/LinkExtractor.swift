import Foundation

enum LinkExtractor {
    static let douyinShort = try! NSRegularExpression(
        pattern: #"https?://v\.douyin\.com/[A-Za-z0-9_\-]+/?"#,
        options: [.caseInsensitive]
    )

    static let anyURL = try! NSRegularExpression(
        pattern: #"https?://[^\s<>"'，。；、！？：（）【】《》「」『』]+"#,
        options: [.caseInsensitive]
    )

    static func extract(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)

        if let m = douyinShort.firstMatch(in: text, range: range) {
            return trim(ns.substring(with: m.range))
        }
        if let m = anyURL.firstMatch(in: text, range: range) {
            return trim(ns.substring(with: m.range))
        }
        return nil
    }

    static func platform(_ urlString: String?) -> String? {
        guard let urlString, let host = URL(string: urlString)?.host?.lowercased() else {
            return nil
        }
        if host == "douyin.com" || host.hasSuffix(".douyin.com") ||
            host == "iesdouyin.com" || host.hasSuffix(".iesdouyin.com") {
            return "douyin"
        }
        if host == "xiaohongshu.com" || host.hasSuffix(".xiaohongshu.com") ||
            host == "xhslink.com" || host.hasSuffix(".xhslink.com") ||
            host == "xhslink.cn" || host.hasSuffix(".xhslink.cn") {
            return "xhs"
        }
        if host == "kuaishou.com" || host.hasSuffix(".kuaishou.com") ||
            host == "gifshow.com" || host.hasSuffix(".gifshow.com") ||
            host == "chenzhongtech.com" || host.hasSuffix(".chenzhongtech.com") {
            return "kuaishou"
        }
        if host == "bilibili.com" || host.hasSuffix(".bilibili.com") ||
            host == "b23.tv" || host.hasSuffix(".b23.tv") {
            return "bilibili"
        }
        return nil
    }

    static func platformName(_ platform: String) -> String {
        switch platform {
        case "douyin": return "抖音"
        case "xhs": return "小红书"
        case "kuaishou": return "快手"
        case "bilibili": return "B站"
        default: return platform
        }
    }

    private static func trim(_ s: String) -> String {
        var value = s
        let trailing = CharacterSet(charactersIn: ".,;)]}，。；！？\"'、")
        while let last = value.unicodeScalars.last, trailing.contains(last) {
            value.removeLast()
        }
        return value
    }
}
