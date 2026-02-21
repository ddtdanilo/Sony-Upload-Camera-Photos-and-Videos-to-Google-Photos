import Foundation

@MainActor
final class MediaBrowserViewModel: ObservableObject {
    @Published var mediaItems: [MediaItem] = []
    @Published var selectedItems: Set<MediaItem> = []
    @Published var isScanning = false
    @Published var filterType: MediaTypeFilter = .all

    private let scannerService: MediaScannerService
    let thumbnailService: ThumbnailService

    init(
        scannerService: MediaScannerService = MediaScannerService(),
        thumbnailService: ThumbnailService = ThumbnailService()
    ) {
        self.scannerService = scannerService
        self.thumbnailService = thumbnailService
    }

    var filteredItems: [MediaItem] {
        switch filterType {
        case .all:
            return mediaItems
        case .photos:
            return mediaItems.filter { $0.mediaType.isPhoto }
        case .videos:
            return mediaItems.filter { $0.mediaType.isVideo }
        case .raw:
            return mediaItems.filter { $0.mediaType == .arw }
        }
    }

    var selectionSummary: String {
        if selectedItems.isEmpty {
            return "No items selected"
        }
        let totalSize = selectedItems.reduce(Int64(0)) { $0 + $1.fileSize }
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return "\(selectedItems.count) items selected (\(formattedSize))"
    }

    func scanVolume(_ volume: CameraVolume) {
        isScanning = true
        selectedItems.removeAll()
        mediaItems.removeAll()

        Task {
            let items = await scannerService.scanVolume(volume)
            mediaItems = items
            isScanning = false
        }
    }

    func toggleSelection(_ item: MediaItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }

    func selectAll() {
        selectedItems = Set(filteredItems)
    }

    func deselectAll() {
        selectedItems.removeAll()
    }
}

enum MediaTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    case raw = "RAW"

    var id: String { rawValue }
}
