import Foundation

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var jobs: [ImportJob] = []
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let apiService: GooglePhotosAPIService

    var completedCount: Int {
        jobs.filter { $0.status == .completed }.count
    }

    var failedCount: Int {
        jobs.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    var totalCount: Int {
        jobs.count
    }

    var overallProgress: Double {
        guard !jobs.isEmpty else { return 0 }
        let progresses = jobs.map { job -> Double in
            switch job.status {
            case .pending: return 0
            case .uploading(let p): return p * 0.9  // 90% for upload
            case .creatingMediaItem: return 0.95
            case .completed: return 1.0
            case .failed: return 0
            }
        }
        return progresses.reduce(0, +) / Double(jobs.count)
    }

    var isComplete: Bool {
        jobs.allSatisfy { $0.status.isTerminal }
    }

    init(apiService: GooglePhotosAPIService) {
        self.apiService = apiService
    }

    func startUpload(items: Set<MediaItem>) {
        guard !isUploading else { return }

        jobs = items.map { ImportJob(mediaItem: $0) }
        isUploading = true
        errorMessage = nil

        Task {
            await processUploads()
        }
    }

    private func processUploads() async {
        // Upload files concurrently with a limit
        await withTaskGroup(of: Void.self) { group in
            var iterator = jobs.makeIterator()
            var activeTasks = 0

            // Start initial batch
            while activeTasks < Constants.App.maxConcurrentUploads,
                  let job = iterator.next() {
                activeTasks += 1
                group.addTask { [weak self] in
                    await self?.uploadSingleFile(job)
                }
            }

            // As each finishes, start the next
            for await _ in group {
                activeTasks -= 1
                if let job = iterator.next() {
                    activeTasks += 1
                    group.addTask { [weak self] in
                        await self?.uploadSingleFile(job)
                    }
                }
            }
        }

        // Batch create media items from successful uploads
        let successfulJobs = jobs.filter { $0.uploadToken != nil }
        if !successfulJobs.isEmpty {
            await batchCreateMediaItems(jobs: successfulJobs)
        }

        isUploading = false
    }

    private func uploadSingleFile(_ job: ImportJob) async {
        await MainActor.run {
            job.status = .uploading(progress: 0)
        }

        do {
            let token = try await apiService.uploadFile(job.mediaItem) { progress in
                Task { @MainActor in
                    job.status = .uploading(progress: progress)
                }
            }

            await MainActor.run {
                job.uploadToken = token
                job.status = .creatingMediaItem
            }
        } catch {
            await MainActor.run {
                job.status = .failed(error: error.localizedDescription)
            }
        }
    }

    private func batchCreateMediaItems(jobs: [ImportJob]) async {
        let tokens = jobs.compactMap { job -> (token: String, fileName: String)? in
            guard let token = job.uploadToken else { return nil }
            return (token, job.mediaItem.fileName)
        }

        do {
            try await apiService.batchCreateMediaItems(uploadTokens: tokens)

            for job in jobs where job.uploadToken != nil {
                job.status = .completed
            }
        } catch {
            errorMessage = error.localizedDescription
            for job in jobs where job.uploadToken != nil {
                if case .failed = job.status { continue }
                job.status = .failed(error: error.localizedDescription)
            }
        }
    }

    func clearCompleted() {
        jobs.removeAll { $0.status == .completed }
    }

    func retryFailed() {
        let failedItems = Set(jobs.compactMap { job -> MediaItem? in
            if case .failed = job.status { return job.mediaItem }
            return nil
        })

        jobs.removeAll { job in
            if case .failed = job.status { return true }
            return false
        }

        if !failedItems.isEmpty {
            let newJobs = failedItems.map { ImportJob(mediaItem: $0) }
            jobs.append(contentsOf: newJobs)

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for job in newJobs {
                        group.addTask { [weak self] in
                            await self?.uploadSingleFile(job)
                        }
                    }
                }

                let successfulRetries = newJobs.filter { $0.uploadToken != nil }
                if !successfulRetries.isEmpty {
                    await batchCreateMediaItems(jobs: successfulRetries)
                }
            }
        }
    }
}
