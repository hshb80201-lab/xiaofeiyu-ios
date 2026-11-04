import Foundation
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var input = ""
    @Published var media: ParsedMedia?
    @Published var parsing = false
    @Published var error: String?
    @Published var suggestion: ClipboardSuggestion?
    @Published var saveMessage: String?

    private var lastClipboard: String?

    /// 只在 App 回到前台时调用；普通文字不弹。
    func checkClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        guard text != lastClipboard else { return }
        lastClipboard = text

        guard input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, media == nil else { return }
        guard let url = LinkExtractor.extract(text),
              let platform = LinkExtractor.platform(url) else { return }

        suggestion = ClipboardSuggestion(
            url: url,
            platform: LinkExtractor.platformName(platform)
        )
    }

    func acceptSuggestion() {
        guard let item = suggestion else { return }
        input = item.url
        suggestion = nil
        UIPasteboard.general.items = []
        Task { await parseNow() }
    }

    func dismissSuggestion() {
        suggestion = nil
    }

    func parseNow() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let url = LinkExtractor.extract(text),
              let platform = LinkExtractor.platform(url) else {
            error = "链接里没有识别到支持的平台"
            return
        }

        parsing = true
        error = nil
        media = nil
        defer { parsing = false }

        do {
            switch platform {
            case "bilibili":
                media = try await BiliParser.parse(url)
            case "douyin":
                media = try await DouyinParser.parse(url)
            case "xhs":
                media = try await XhsParser.parse(url)
            case "kuaishou":
                media = try await KuaishouParser.parse(url)
            default:
                error = "\(LinkExtractor.platformName(platform)) 解析器待接入"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveVideo() {
        guard let media else { return }
        saveMessage = "开始下载…"
        Task {
            do {
                try await AppDownloader.saveVideo(media) { p in
                    Task { @MainActor in
                        self.saveMessage = "下载中 \(Int(p * 100))%"
                    }
                }
                saveMessage = "视频已保存到相册"
            } catch {
                saveMessage = error.localizedDescription
            }
        }
    }

    func saveImage(index: Int) {
        guard let media, media.imageURLs.indices.contains(index) else { return }
        let url = media.imageURLs[index]
        saveMessage = "开始下载图片…"
        Task {
            do {
                let file = Downloader.tempFile(ext: "jpg")
                try await Downloader.download(url, headers: media.headers, to: file)
                try await Downloader.saveImageToPhotos(file)
                saveMessage = "图片已保存到相册"
            } catch {
                saveMessage = error.localizedDescription
            }
        }
    }

    func saveLivePhoto(index: Int) {
        guard let media,
              media.imageURLs.indices.contains(index),
              media.liveVideoURLs.indices.contains(index),
              let liveURL = media.liveVideoURLs[index] else { return }

        let imageURL = media.imageURLs[index]
        saveMessage = "下载实况照片…"
        Task {
            do {
                let jpg = Downloader.tempFile(ext: "jpg")
                let mp4 = Downloader.tempFile(ext: "mp4")
                try await Downloader.download(imageURL, headers: media.headers, to: jpg)
                try await Downloader.download(liveURL, headers: media.headers, to: mp4)
                try await AppDownloader.saveLivePhoto(jpeg: jpg, video: mp4)
                saveMessage = "实况照片已保存到相册"
            } catch {
                saveMessage = error.localizedDescription
            }
        }
    }

    func saveAudio() {
        guard let media else { return }
        saveMessage = "开始提取音频…"
        Task {
            do {
                try await AppDownloader.saveAudio(media) { p in
                    Task { @MainActor in
                        self.saveMessage = "音频处理中 \(Int(p * 100))%"
                    }
                }
                saveMessage = "音频已保存到文件 App"
            } catch {
                saveMessage = error.localizedDescription
            }
        }
    }
}
