import Foundation
import AVFoundation

enum AudioExtractor {
    /// 从视频文件剥离画面，仅导出 .m4a（AAC）。
    static func extract(from video: URL, to output: URL) async throws {
        let asset = AVURLAsset(url: video)
        guard let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first else {
            throw MediaError.missingTrack("音频")
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MediaError.exportFailed("创建音频轨失败")
        }

        let duration = try await asset.load(.duration)
        try track.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceAudio,
            at: .zero
        )

        try await AVMerger.export(
            asset: composition,
            preset: AVAssetExportPresetAppleM4A,
            output: output,
            fileType: .m4a
        )
    }
}
