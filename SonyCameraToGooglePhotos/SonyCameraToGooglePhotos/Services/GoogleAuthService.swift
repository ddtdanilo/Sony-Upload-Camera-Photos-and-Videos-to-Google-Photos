import Foundation
import AppKit
import CommonCrypto

final class GoogleAuthService: ObservableObject {
    private let keychainService: KeychainService

    @Published var accessToken: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isAuthenticated = false

    // Stored token data
    private var refreshToken: String?
    private var tokenExpirationDate: Date?

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Session Restore

    func restoreSession() async {
        guard let data = try? keychainService.load(forKey: Constants.App.keychainAuthStateKey),
              let tokenData = try? JSONDecoder().decode(StoredTokenData.self, from: data) else {
            return
        }

        self.refreshToken = tokenData.refreshToken
        self.userEmail = tokenData.email
        self.userName = tokenData.name

        // Refresh the access token
        await refreshAccessToken()
    }

    // MARK: - Sign In (OAuth Authorization Code Flow with PKCE)

    func signIn() async throws {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Start loopback server to receive the redirect
        let (code, _) = try await startLoopbackServerAndAuthorize(
            codeChallenge: codeChallenge
        )

        // Exchange authorization code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier
        )

        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(
            TimeInterval(tokenResponse.expiresIn)
        )

        // Fetch user info
        try await fetchUserInfo()

        self.isAuthenticated = true

        // Persist to keychain
        try saveSession()
    }

    // MARK: - Sign Out

    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        userEmail = nil
        userName = nil
        isAuthenticated = false

        try? keychainService.delete(forKey: Constants.App.keychainAuthStateKey)
    }

    // MARK: - Token Management

    func getValidAccessToken() async throws -> String {
        if let token = accessToken, let expiration = tokenExpirationDate,
           expiration > Date().addingTimeInterval(60) {
            return token
        }

        await refreshAccessToken()

        guard let token = accessToken else {
            throw AuthError.notAuthenticated
        }
        return token
    }

    private func refreshAccessToken() async {
        guard let refreshToken = refreshToken else { return }

        do {
            let tokenResponse = try await performTokenRefresh(refreshToken: refreshToken)
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                self.tokenExpirationDate = Date().addingTimeInterval(
                    TimeInterval(tokenResponse.expiresIn)
                )
                self.isAuthenticated = true
                if let newRefresh = tokenResponse.refreshToken {
                    self.refreshToken = newRefresh
                }
            }
            try saveSession()
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.accessToken = nil
            }
        }
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Loopback Server + Authorization

    private func startLoopbackServerAndAuthorize(
        codeChallenge: String
    ) async throws -> (code: String, state: String) {
        // Create a simple HTTP server on a random port
        let serverSocket = try createServerSocket()
        let port = try getSocketPort(serverSocket)

        // Track the redirect URI for the token exchange
        self.exchangeRedirectURI = "http://127.0.0.1:\(port)"

        let state = UUID().uuidString

        // Build authorization URL
        var components = URLComponents(url: Constants.OAuth.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.OAuth.clientID),
            URLQueryItem(name: "redirect_uri", value: "http://127.0.0.1:\(port)"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Constants.OAuth.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let authURL = components.url!

        // Open browser
        await MainActor.run {
            NSWorkspace.shared.open(authURL)
        }

        // Wait for the redirect callback
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let (code, receivedState) = try self.acceptConnection(
                        serverSocket: serverSocket,
                        expectedState: state,
                        port: port
                    )
                    close(serverSocket)
                    continuation.resume(returning: (code, receivedState))
                } catch {
                    close(serverSocket)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func createServerSocket() throws -> Int32 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { throw AuthError.serverCreationFailed }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // Random port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(sock)
            throw AuthError.serverCreationFailed
        }

        guard listen(sock, 1) == 0 else {
            close(sock)
            throw AuthError.serverCreationFailed
        }

        return sock
    }

    private func getSocketPort(_ sock: Int32) throws -> UInt16 {
        var addr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                getsockname(sock, sockaddrPtr, &addrLen)
            }
        }
        guard result == 0 else { throw AuthError.serverCreationFailed }
        return UInt16(bigEndian: addr.sin_port)
    }

    private func acceptConnection(
        serverSocket: Int32,
        expectedState: String,
        port: UInt16
    ) throws -> (code: String, state: String) {
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                accept(serverSocket, sockaddrPtr, &clientAddrLen)
            }
        }

        guard clientSocket >= 0 else { throw AuthError.connectionFailed }

        // Read the HTTP request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else {
            close(clientSocket)
            throw AuthError.connectionFailed
        }

        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Parse the GET request for the code and state
        guard let firstLine = request.split(separator: "\r\n").first,
              let urlString = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://127.0.0.1:\(port)\(urlString)") else {
            close(clientSocket)
            throw AuthError.invalidCallback
        }

        let queryItems = components.queryItems ?? []
        let code = queryItems.first { $0.name == "code" }?.value
        let state = queryItems.first { $0.name == "state" }?.value
        let error = queryItems.first { $0.name == "error" }?.value

        // Send response to browser
        let responseBody: String
        if code != nil {
            responseBody = """
            <html><body style="font-family: -apple-system, sans-serif; text-align: center; padding: 60px;">
            <h1>Authentication Successful</h1>
            <p>You can close this window and return to the app.</p>
            </body></html>
            """
        } else {
            responseBody = """
            <html><body style="font-family: -apple-system, sans-serif; text-align: center; padding: 60px;">
            <h1>Authentication Failed</h1>
            <p>Error: \(error ?? "Unknown error"). Please try again.</p>
            </body></html>
            """
        }

        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(responseBody)"
        httpResponse.withCString { ptr in
            _ = write(clientSocket, ptr, strlen(ptr))
        }
        close(clientSocket)

        guard let code = code, let state = state else {
            throw AuthError.authorizationFailed(error ?? "No code received")
        }

        guard state == expectedState else {
            throw AuthError.stateMismatch
        }

        return (code, state)
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String
    ) async throws -> TokenResponse {
        // Get the port from the redirect that was used (we need to reconstruct it)
        // For simplicity, we'll pass the redirect URI through
        var request = URLRequest(url: Constants.OAuth.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Note: for the token exchange, Google needs the exact redirect_uri used during authorization.
        // Since we used a random port, we need to track it. For now, we use a simplified approach.
        let params = [
            "code": code,
            "client_id": Constants.OAuth.clientID,
            "client_secret": Constants.OAuth.clientSecret,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier,
            "redirect_uri": exchangeRedirectURI ?? "http://127.0.0.1"
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(body)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // Track the redirect URI used during authorization
    private var exchangeRedirectURI: String?

    private func performTokenRefresh(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: Constants.OAuth.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": Constants.OAuth.clientID,
            "client_secret": Constants.OAuth.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenRefreshFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - User Info

    private func fetchUserInfo() async throws {
        guard let token = accessToken else { return }

        var request = URLRequest(url: Constants.OAuth.userInfoEndpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            await MainActor.run {
                self.userEmail = json["email"] as? String
                self.userName = json["name"] as? String
            }
        }
    }

    // MARK: - Persistence

    private func saveSession() throws {
        let tokenData = StoredTokenData(
            refreshToken: refreshToken ?? "",
            email: userEmail,
            name: userName
        )
        let data = try JSONEncoder().encode(tokenData)
        try keychainService.save(data: data, forKey: Constants.App.keychainAuthStateKey)
    }
}

// MARK: - Supporting Types

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct StoredTokenData: Codable {
    let refreshToken: String
    let email: String?
    let name: String?
}

enum AuthError: LocalizedError {
    case serverCreationFailed
    case connectionFailed
    case invalidCallback
    case authorizationFailed(String)
    case stateMismatch
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .serverCreationFailed:
            return "Failed to create local authentication server"
        case .connectionFailed:
            return "Failed to receive authentication callback"
        case .invalidCallback:
            return "Invalid authentication callback received"
        case .authorizationFailed(let error):
            return "Authorization failed: \(error)"
        case .stateMismatch:
            return "Authentication state mismatch — possible security issue"
        case .tokenExchangeFailed(let details):
            return "Token exchange failed: \(details)"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        }
    }
}
