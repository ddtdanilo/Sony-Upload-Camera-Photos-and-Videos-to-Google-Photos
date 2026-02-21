import Foundation
import UniformTypeIdentifiers

enum MediaType: String, CaseIterable, Identifiable, Codable {
    case jpeg
    case arw
    case mp4

    var id: String { rawValue }

    var fileExtensions: [String] {
        switch self {
        case .jpeg: return ["jpg", "jpeg"]
        case .arw: return ["arw"]
        case .mp4: return ["mp4"]
        }
    }

    var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .arw: return "image/x-sony-arw"
        case .mp4: return "video/mp4"
        }
    }

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .arw: return "RAW (ARW)"
        case .mp4: return "Video (MP4)"
        }
    }

    var isVideo: Bool {
        self == .mp4
    }

    var isPhoto: Bool {
        !isVideo
    }

    static func from(fileExtension ext: String) -> MediaType? {
        let lower = ext.lowercased()
        return allCases.first { $0.fileExtensions.contains(lower) }
    }
}
