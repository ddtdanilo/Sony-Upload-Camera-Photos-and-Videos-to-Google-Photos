import SwiftUI

@main
struct SonyCameraToGooglePhotosApp: App {
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var volumeViewModel = VolumeDetectionViewModel()
    @StateObject private var browserViewModel = MediaBrowserViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(volumeViewModel)
                .environmentObject(browserViewModel)
                .task {
                    await authViewModel.restoreSession()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
