import Foundation

/// 业务层：解析结果 -> 下载 -> 合轨/提音频/写相册。
enum AppDownloader {
    static func saveVideo(_ media: ParsedMedia, progress: @escaping (Double) -> Void) async throws {
        guard let videoURL = media.videoURL else { throw MediaError.missingTrack("视频") }

        if let audioURL = media.audioURL {
            let videoFile = Downloader.tempFile(ext: "m4s")
            let audioFile = Downloader.tempFile(ext: "m4s")
            try await Downloader.download(videoURL, headers: media.headers, to: videoFile)
            progress(0.45)
            try await Downloader.download(audioURL, headers: media.headers, to: audioFile)
            progress(0.8)

            let merged = Downloader.tempFile(ext: "mp4")
            try await AVMerger.merge(video: videoFile, audio: audioFile, output: merged)
            progress(0.95)
            try await Downloader.saveVideoToPhotos(merged)
            progress(1)
            return
        }

        let videoFile = Downloader.tempFile(ext: "mp4")
        try await Downloader.download(videoURL, headers: media.headers, to: videoFile)
        progress(0.9)
        try await Downloader.saveVideoToPhotos(videoFile)
        progress(1)
    }

    static func saveAudio(_ media: ParsedMedia, progress: @escaping (Double) -> Void) async throws {
        var source: URL
        var isVideoSource = false

        if let audioURL = media.audioURL ?? media.musicURL {
            source = Downloader.tempFile(ext: audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension)
            try await Downloader.download(audioURL, headers: media.headers, to: source)
        } else {
            guard let videoURL = media.videoURL else { throw MediaError.missingTrack("音频") }
            source = Downloader.tempFile(ext: "mp4")
            try await Downloader.download(videoURL, headers: media.headers, to: source)
            isVideoSource = true
        }
        progress(0.6)

        let output = Downloader.tempFile(ext: "m4a")
        do {
            try await AudioExtractor.extract(from: source, to: output)
            try await saveAudioFile(output)
        } catch {
            // 源本身就是 mp3/m4a 时直接入库
            if !isVideoSource {
                try await saveAudioFile(source)
            } else {
                throw error
            }
        }
        progress(1)
    }

    private static func saveAudioFile(_ file: URL) async throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("小肥鱼-\(file.lastPathComponent)")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: file, to: dest)
    }

    static func saveLivePhoto(jpeg: URL, video: URL) async throws {
        try await LivePhotoWriter.save(jpeg: jpeg, video: video)
    }
}
