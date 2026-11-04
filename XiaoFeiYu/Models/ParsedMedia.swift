import Foundation

struct ParsedMedia: Identifiable {
    let id = UUID()
    var platform: String          // douyin / kuaishou / xhs / bilibili
    var type: String              // video / image / dash
    var title: String
    var author: String
    var videoURL: URL?
    var audioURL: URL?           // B站 DASH 音频
    var musicURL: URL?           // 抖音独立配乐
    var imageURLs: [URL] = []
    var liveVideoURLs: [URL?] = [] // 与 imageURLs 对齐
    var coverURL: URL?
    var headers: [String: String] = [:]
    var shareURL: String = ""
    var quality: String = ""

    var isVideo: Bool { type == "video" || type == "dash" }
    var isDash: Bool { type == "dash" && audioURL != nil }

    var platformName: String {
        switch platform {
        case "douyin": return "抖音"
        case "kuaishou": return "快手"
        case "xhs": return "小红书"
        case "bilibili": return "B站"
        default: return platform
        }
    }
}

struct ClipboardSuggestion: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let platform: String

    static func == (lhs: ClipboardSuggestion, rhs: ClipboardSuggestion) -> Bool {
        lhs.url == rhs.url
    }
}
