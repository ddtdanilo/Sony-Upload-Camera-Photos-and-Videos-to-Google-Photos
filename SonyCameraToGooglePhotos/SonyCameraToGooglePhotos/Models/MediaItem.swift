import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let fileName: String
    let mediaType: MediaType
    let fileSize: Int64
    let creationDate: Date?

    init(url: URL, mediaType: MediaType, fileSize: Int64, creationDate: Date?) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.creationDate = creationDate
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isVideo: Bool {
        mediaType.isVideo
    }
}
