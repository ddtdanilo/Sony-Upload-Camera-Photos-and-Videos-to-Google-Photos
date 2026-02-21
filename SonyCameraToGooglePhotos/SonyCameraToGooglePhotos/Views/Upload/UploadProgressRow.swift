import SwiftUI

struct UploadProgressRow: View {
    @ObservedObject var job: ImportJob

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: job.mediaItem.isVideo ? "video.fill" : "photo.fill")
                .foregroundStyle(iconColor)
                .frame(width: 24)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(job.mediaItem.fileName)
                    .font(.body)
                    .lineLimit(1)

                Text(job.mediaItem.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status
            statusView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            Text("Waiting")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .uploading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

        case .creatingMediaItem:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Creating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private var iconColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        default: return .blue
        }
    }
}
