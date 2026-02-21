import Foundation
import AppKit
import AVFoundation
import QuickLookThumbnailing

final class ThumbnailService {
    private let cache = NSCache<NSURL, NSImage>()
    private let thumbnailSize: CGFloat

    init(thumbnailSize: CGFloat = Constants.App.thumbnailSize) {
        self.thumbnailSize = thumbnailSize
        cache.countLimit = 500
    }

    func thumbnail(for item: MediaItem) async -> NSImage? {
        // Check cache
        if let cached = cache.object(forKey: item.url as NSURL) {
            return cached
        }

        let image: NSImage?

        if item.isVideo {
            image = await generateVideoThumbnail(url: item.url)
        } else {
            image = await generateImageThumbnail(url: item.url)
        }

        if let image = image {
            cache.setObject(image, forKey: item.url as NSURL)
        }

        return image
    }

    // MARK: - Image Thumbnails

    private func generateImageThumbnail(url: URL) async -> NSImage? {
        // Try QuickLook first (handles ARW/RAW)
        if let qlImage = await generateQuickLookThumbnail(url: url) {
            return qlImage
        }

        // Fallback to NSImage for JPEG
        return resizedImage(from: url)
    }

    private func generateQuickLookThumbnail(url: URL) async -> NSImage? {
        let size = CGSize(width: thumbnailSize, height: thumbnailSize)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }

    private func resizedImage(from url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let originalSize = image.size
        let scale = min(thumbnailSize / originalSize.width, thumbnailSize / originalSize.height)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        return resized
    }

    // MARK: - Video Thumbnails

    private func generateVideoThumbnail(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailSize * 2, height: thumbnailSize * 2)

        let time = CMTime(seconds: 1, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return NSImage(cgImage: cgImage, size: NSSize(width: thumbnailSize, height: thumbnailSize))
        } catch {
            return nil
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
