import Foundation

enum Constants {
    enum OAuth {
        // Replace these with your Google Cloud Console credentials
        static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
        static let clientSecret = "YOUR_CLIENT_SECRET"

        static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
        static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!

        static let scopes = [
            "https://www.googleapis.com/auth/photoslibrary.appendonly",
            "openid",
            "profile",
            "email"
        ]

        // AppAuth uses a loopback redirect for desktop apps
        static let redirectURI = URL(string: "http://127.0.0.1")!
    }

    enum GooglePhotosAPI {
        static let uploadURL = URL(string: "https://photoslibrary.googleapis.com/v1/uploads")!
        static let batchCreateURL = URL(string: "https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate")!

        /// Files larger than this threshold use resumable uploads
        static let resumableUploadThreshold: Int64 = 5 * 1024 * 1024 // 5 MB

        /// Maximum items per batchCreate call
        static let maxBatchSize = 50
    }

    enum App {
        static let keychainServiceName = "com.sonycamera.googlephotos"
        static let keychainAuthStateKey = "google_auth_state"

        /// Known Sony camera DCIM subfolder patterns
        static let sonyPhotoFolderPattern = "MSDCF"

        /// Sony video folder path relative to volume root
        static let sonyVideoPath = "PRIVATE/M4ROOT/CLIP"

        /// Supported file extensions for scanning
        static let supportedExtensions: Set<String> = ["jpg", "jpeg", "arw", "mp4"]

        /// Maximum concurrent uploads
        static let maxConcurrentUploads = 3

        /// Thumbnail size for the grid view
        static let thumbnailSize: CGFloat = 200
    }
}
