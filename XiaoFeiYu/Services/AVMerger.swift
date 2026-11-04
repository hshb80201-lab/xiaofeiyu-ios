import Foundation
import AVFoundation

enum MediaError: LocalizedError {
    case missingTrack(String)
    case exportFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingTrack(let name): return "缺少\(name)轨道"
        case .exportFailed(let message): return message
        case .cancelled: return "已取消"
        }
    }
}

enum AVMerger {
    /// 视频轨 + 音频轨无损合并（passthrough，不重编码）。
    static func merge(video: URL, audio: URL, output: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: audio)

        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw MediaError.missingTrack("视频")
        }
        guard let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw MediaError.missingTrack("音频")
        }

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ), let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MediaError.exportFailed("创建合轨失败")
        }

        let videoDuration = try await videoAsset.load(.duration)
        try videoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceVideo,
            at: .zero
        )
        videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)

        let audioDuration = try await audioAsset.load(.duration)
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: audioDuration),
            of: sourceAudio,
            at: .zero
        )

        try await export(
            asset: composition,
            preset: AVAssetExportPresetPassthrough,
            output: output,
            fileType: .mp4
        )
    }

    static func export(
        asset: AVAsset,
        preset: String,
        output: URL,
        fileType: AVFileType
    ) async throws {
        if FileManager.default.fileExists(atPath: output.path) {
            try? FileManager.default.removeItem(at: output)
        }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw MediaError.exportFailed("当前素材不支持该导出预设")
        }
        exporter.outputURL = output
        exporter.outputFileType = fileType
        exporter.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        if exporter.status != .completed {
            if exporter.status == .cancelled { throw MediaError.cancelled }
            throw MediaError.exportFailed(exporter.error?.localizedDescription ?? "导出失败")
        }
    }
}
