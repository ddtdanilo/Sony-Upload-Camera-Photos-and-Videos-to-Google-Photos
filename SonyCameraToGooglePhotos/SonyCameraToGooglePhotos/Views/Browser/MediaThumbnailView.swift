import SwiftUI

struct MediaThumbnailView: View {
    let item: MediaItem
    let isSelected: Bool
    let thumbnailService: ThumbnailService
    let onTap: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail image
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                    }
                }
                .frame(width: Constants.App.thumbnailSize, height: Constants.App.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Video badge
                if item.isVideo {
                    Label("Video", systemImage: "video.fill")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                }

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            }

            // File name and size
            VStack(spacing: 1) {
                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.formattedFileSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Constants.App.thumbnailSize)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            thumbnail = await thumbnailService.thumbnail(for: item)
        }
    }
}
