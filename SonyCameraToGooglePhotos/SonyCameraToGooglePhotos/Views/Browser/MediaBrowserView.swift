import SwiftUI

struct MediaBrowserView: View {
    @EnvironmentObject var volumeViewModel: VolumeDetectionViewModel
    @EnvironmentObject var browserViewModel: MediaBrowserViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    @State private var showUploadSheet = false
    @StateObject private var uploadViewModel: UploadViewModel

    private let columns = [
        GridItem(.adaptive(minimum: Constants.App.thumbnailSize + 16), spacing: 12)
    ]

    init() {
        // Initialize with a placeholder - will be replaced when auth is available
        _uploadViewModel = StateObject(wrappedValue: UploadViewModel(
            apiService: GooglePhotosAPIService(authService: GoogleAuthService())
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Content
            if browserViewModel.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning volume...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browserViewModel.mediaItems.isEmpty {
                emptyState
            } else {
                mediaGrid
            }
        }
        .onChange(of: volumeViewModel.selectedVolume) { newVolume in
            if let volume = newVolume {
                browserViewModel.scanVolume(volume)
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadQueueView(
                uploadViewModel: UploadViewModel(
                    apiService: GooglePhotosAPIService(authService: authViewModel.authService)
                )
            )
            .frame(minWidth: 500, minHeight: 400)
        }
    }

    private var toolbar: some View {
        HStack {
            VolumePickerView()

            Spacer()

            // Filter picker
            Picker("Filter", selection: $browserViewModel.filterType) {
                ForEach(MediaTypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 250)

            Spacer()

            // Selection controls
            HStack(spacing: 8) {
                Text(browserViewModel.selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Select All") {
                    browserViewModel.selectAll()
                }
                .buttonStyle(.borderless)
                .disabled(browserViewModel.filteredItems.isEmpty)

                Button("Upload") {
                    startUpload()
                }
                .buttonStyle(.borderedProminent)
                .disabled(browserViewModel.selectedItems.isEmpty)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sdcard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if volumeViewModel.selectedVolume == nil {
                Text("No volume selected")
                    .font(.title3)
                Text("Connect a camera or insert an SD card")
                    .foregroundStyle(.secondary)
            } else {
                Text("No media files found")
                    .font(.title3)
                Text("No supported files were found on this volume")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediaGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(browserViewModel.filteredItems) { item in
                    MediaThumbnailView(
                        item: item,
                        isSelected: browserViewModel.selectedItems.contains(item),
                        thumbnailService: browserViewModel.thumbnailService,
                        onTap: {
                            browserViewModel.toggleSelection(item)
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func startUpload() {
        showUploadSheet = true
    }
}
