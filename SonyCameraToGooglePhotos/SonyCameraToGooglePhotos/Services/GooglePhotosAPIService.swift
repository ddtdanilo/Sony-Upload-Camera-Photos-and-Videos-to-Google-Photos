import Foundation

final class GooglePhotosAPIService {
    private let authService: GoogleAuthService

    init(authService: GoogleAuthService) {
        self.authService = authService
    }

    // MARK: - Upload Bytes

    /// Upload a file's bytes to Google Photos. Returns an upload token.
    func uploadFile(
        _ mediaItem: MediaItem,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let token = try await authService.getValidAccessToken()
        let fileData = try Data(contentsOf: mediaItem.url)

        if mediaItem.fileSize > Constants.GooglePhotosAPI.resumableUploadThreshold {
            return try await resumableUpload(
                fileData: fileData,
                fileName: mediaItem.fileName,
                mimeType: mediaItem.mediaType.mimeType,
                accessToken: token,
                progressHandler: progressHandler
            )
        } else {
            return try await simpleUpload(
                fileData: fileData,
                fileName: mediaItem.fileName,
                mimeType: mediaItem.mediaType.mimeType,
                accessToken: token,
                progressHandler: progressHandler
            )
        }
    }

    // MARK: - Simple Upload

    private func simpleUpload(
        fileData: Data,
        fileName: String,
        mimeType: String,
        accessToken: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        var request = URLRequest(url: Constants.GooglePhotosAPI.uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Content-Type")
        request.setValue("raw", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue(fileName, forHTTPHeaderField: "X-Goog-Upload-File-Name")
        request.httpBody = fileData

        progressHandler(0.5) // Simple upload doesn't support granular progress

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw UploadError.uploadFailed("Upload failed: \(body)")
        }

        guard let uploadToken = String(data: data, encoding: .utf8), !uploadToken.isEmpty else {
            throw UploadError.noUploadToken
        }

        progressHandler(1.0)
        return uploadToken
    }

    // MARK: - Resumable Upload

    private func resumableUpload(
        fileData: Data,
        fileName: String,
        mimeType: String,
        accessToken: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        // Step 1: Initiate resumable upload
        let uploadURL = try await initiateResumableUpload(
            fileSize: fileData.count,
            mimeType: mimeType,
            fileName: fileName,
            accessToken: accessToken
        )

        // Step 2: Upload data in chunks
        let chunkSize = 8 * 1024 * 1024 // 8 MB chunks
        var offset = 0

        while offset < fileData.count {
            let end = min(offset + chunkSize, fileData.count)
            let chunk = fileData[offset..<end]

            let isLastChunk = end == fileData.count

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(
                "bytes \(offset)-\(end - 1)/\(fileData.count)",
                forHTTPHeaderField: "Content-Range"
            )
            request.httpBody = chunk

            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            if isLastChunk {
                guard httpResponse?.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw UploadError.uploadFailed("Resumable upload failed: \(body)")
                }

                guard let uploadToken = String(data: data, encoding: .utf8), !uploadToken.isEmpty else {
                    throw UploadError.noUploadToken
                }

                progressHandler(1.0)
                return uploadToken
            } else {
                // For intermediate chunks, expect 308 Resume Incomplete
                guard httpResponse?.statusCode == 200 || httpResponse?.statusCode == 308 else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw UploadError.uploadFailed("Chunk upload failed: \(body)")
                }
            }

            offset = end
            let progress = Double(offset) / Double(fileData.count)
            progressHandler(progress)
        }

        throw UploadError.uploadFailed("Upload ended without receiving token")
    }

    private func initiateResumableUpload(
        fileSize: Int,
        mimeType: String,
        fileName: String,
        accessToken: String
    ) async throws -> URL {
        var request = URLRequest(url: Constants.GooglePhotosAPI.uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Content-Type")
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.setValue(fileName, forHTTPHeaderField: "X-Goog-Upload-File-Name")
        request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue(String(fileSize), forHTTPHeaderField: "X-Goog-Upload-Raw-Size")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let uploadURLString = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-URL"),
              let uploadURL = URL(string: uploadURLString) else {
            throw UploadError.resumableInitFailed
        }

        return uploadURL
    }

    // MARK: - Create Media Items

    /// Create media items from upload tokens (max 50 per call)
    func batchCreateMediaItems(uploadTokens: [(token: String, fileName: String)]) async throws {
        let token = try await authService.getValidAccessToken()

        // Process in batches of 50
        for batch in uploadTokens.chunked(into: Constants.GooglePhotosAPI.maxBatchSize) {
            let newMediaItems = batch.map { item -> [String: Any] in
                return [
                    "description": item.fileName,
                    "simpleMediaItem": [
                        "uploadToken": item.token,
                        "fileName": item.fileName
                    ]
                ]
            }

            let body: [String: Any] = ["newMediaItems": newMediaItems]
            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: Constants.GooglePhotosAPI.batchCreateURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                throw UploadError.batchCreateFailed(responseBody)
            }
        }
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case uploadFailed(String)
    case noUploadToken
    case resumableInitFailed
    case batchCreateFailed(String)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let details):
            return "Upload failed: \(details)"
        case .noUploadToken:
            return "No upload token received from server"
        case .resumableInitFailed:
            return "Failed to initiate resumable upload"
        case .batchCreateFailed(let details):
            return "Failed to create media items: \(details)"
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
