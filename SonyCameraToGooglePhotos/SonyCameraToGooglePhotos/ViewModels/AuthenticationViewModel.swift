import Foundation

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let authService: GoogleAuthService

    init(authService: GoogleAuthService = GoogleAuthService()) {
        self.authService = authService
    }

    func restoreSession() async {
        isLoading = true
        await authService.restoreSession()
        isAuthenticated = authService.isAuthenticated
        userEmail = authService.userEmail
        userName = authService.userName
        isLoading = false
    }

    func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn()
                isAuthenticated = authService.isAuthenticated
                userEmail = authService.userEmail
                userName = authService.userName
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func signOut() {
        authService.signOut()
        isAuthenticated = false
        userEmail = nil
        userName = nil
        errorMessage = nil
    }
}
