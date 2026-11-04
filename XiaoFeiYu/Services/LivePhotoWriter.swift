import Foundation
import AVFoundation
import Photos

enum LivePhotoWriter {
    /// JPG + MOV 写成 iOS 原生 Live Photo。
    static func save(jpeg: URL, video: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "LivePhoto", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "没有相册写入权限"])
        }

        let movURL = try await ensureMOV(video)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()

            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.originalFilename = jpeg.lastPathComponent
            photoOptions.shouldMoveFile = false
            request.addResource(with: .photo, fileURL: jpeg, options: photoOptions)

            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.originalFilename = movURL.lastPathComponent
            videoOptions.shouldMoveFile = false
            request.addResource(with: .pairedVideo, fileURL: movURL, options: videoOptions)
        }
    }

    /// 普通 MP4 需要先转成 MOV 才能作为 pairedVideo。
    private static func ensureMOV(_ video: URL) async throws -> URL {
        if video.pathExtension.lowercased() == "mov" { return video }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        try await AVMerger.export(
            asset: AVURLAsset(url: video),
            preset: AVAssetExportPresetPassthrough,
            output: output,
            fileType: .mov
        )
        return output
    }
}
