import Foundation

enum ImportJobStatus: Equatable {
    case pending
    case uploading(progress: Double)
    case creatingMediaItem
    case completed
    case failed(error: String)

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .pending:
            return "Waiting..."
        case .uploading(let progress):
            let pct = Int(progress * 100)
            return "Uploading \(pct)%"
        case .creatingMediaItem:
            return "Creating media item..."
        case .completed:
            return "Done"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

class ImportJob: Identifiable, ObservableObject {
    let id: UUID
    let mediaItem: MediaItem

    @Published var status: ImportJobStatus = .pending
    @Published var uploadToken: String?

    init(mediaItem: MediaItem) {
        self.id = UUID()
        self.mediaItem = mediaItem
    }
}
