import SwiftUI

struct UploadQueueView: View {
    @ObservedObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var browserViewModel: MediaBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding()

            Divider()

            // Upload list
            if uploadViewModel.jobs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(uploadViewModel.jobs) { job in
                        UploadProgressRow(job: job)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer
            footer
                .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Upload Queue")
                    .font(.title2)
                    .fontWeight(.semibold)

                if !uploadViewModel.jobs.isEmpty {
                    Text("\(uploadViewModel.completedCount)/\(uploadViewModel.totalCount) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if uploadViewModel.isUploading {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: uploadViewModel.overallProgress)
                        .frame(width: 120)
                    Text("\(Int(uploadViewModel.overallProgress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No uploads in queue")
                .font(.title3)

            if !browserViewModel.selectedItems.isEmpty {
                Button("Upload \(browserViewModel.selectedItems.count) Selected Items") {
                    uploadViewModel.startUpload(items: browserViewModel.selectedItems)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Select files in the browser to upload")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if let error = uploadViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Spacer()

            if uploadViewModel.failedCount > 0 {
                Button("Retry Failed") {
                    uploadViewModel.retryFailed()
                }
                .buttonStyle(.bordered)
            }

            if uploadViewModel.completedCount > 0 {
                Button("Clear Completed") {
                    uploadViewModel.clearCompleted()
                }
                .buttonStyle(.bordered)
            }

            if !uploadViewModel.isUploading && uploadViewModel.jobs.isEmpty {
                Button("Start Upload") {
                    uploadViewModel.startUpload(items: browserViewModel.selectedItems)
                }
                .buttonStyle(.borderedProminent)
                .disabled(browserViewModel.selectedItems.isEmpty)
            }

            Button("Close") {
                dismiss()
            }
        }
    }
}
