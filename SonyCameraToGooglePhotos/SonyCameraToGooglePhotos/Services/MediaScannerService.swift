import Foundation

final class MediaScannerService {
    /// Scan a Sony camera volume for media files
    func scanVolume(_ volume: CameraVolume) async -> [MediaItem] {
        var items: [MediaItem] = []

        // Scan DCIM folders for photos
        let dcimURL = volume.url.appendingPathComponent("DCIM")
        items.append(contentsOf: await scanDirectory(dcimURL))

        // Scan Sony video folder
        let videoURL = volume.url.appendingPathComponent(Constants.App.sonyVideoPath)
        items.append(contentsOf: await scanDirectory(videoURL))

        // Sort by creation date (newest first)
        items.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        return items
    }

    /// Recursively scan a directory for supported media files
    private func scanDirectory(_ url: URL) async -> [MediaItem] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        var items: [MediaItem] = []

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey]
            ),
                  resourceValues.isRegularFile == true else {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard Constants.App.supportedExtensions.contains(ext),
                  let mediaType = MediaType.from(fileExtension: ext) else {
                continue
            }

            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let creationDate = resourceValues.creationDate

            let item = MediaItem(
                url: fileURL,
                mediaType: mediaType,
                fileSize: fileSize,
                creationDate: creationDate
            )
            items.append(item)
        }

        return items
    }
}
