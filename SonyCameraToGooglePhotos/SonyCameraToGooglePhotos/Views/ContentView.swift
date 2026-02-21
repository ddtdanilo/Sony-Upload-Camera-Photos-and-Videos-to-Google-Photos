import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var volumeViewModel: VolumeDetectionViewModel
    @EnvironmentObject var browserViewModel: MediaBrowserViewModel

    @State private var selectedTab: SidebarTab = .browse

    enum SidebarTab: String, CaseIterable, Identifiable {
        case browse = "Browse"
        case upload = "Upload"
        case account = "Account"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .browse: return "photo.on.rectangle"
            case .upload: return "icloud.and.arrow.up"
            case .account: return "person.circle"
            }
        }
    }

    var body: some View {
        if !Constants.OAuth.isConfigured {
            SetupGuideView()
        } else if authViewModel.isLoading {
            ProgressView("Restoring session...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !authViewModel.isAuthenticated {
            LoginView()
        } else {
            NavigationSplitView {
                List(SidebarTab.allCases, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
                .navigationSplitViewColumnWidth(min: 150, ideal: 180)
                .listStyle(.sidebar)
            } detail: {
                switch selectedTab {
                case .browse:
                    MediaBrowserView()
                case .upload:
                    UploadQueueView(
                        uploadViewModel: UploadViewModel(
                            apiService: GooglePhotosAPIService(
                                authService: authViewModel.authService
                            )
                        )
                    )
                case .account:
                    AccountView()
                }
            }
        }
    }
}
