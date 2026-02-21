import SwiftUI

struct SetupGuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Google API Credentials Required")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("This app needs OAuth credentials to connect to Google Photos.\nFollow the steps below to configure them.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                stepView(number: 1, text: "Go to the Google Cloud Console and create a project (or use an existing one).") {
                    openURL(URL(string: "https://console.cloud.google.com/")!)
                }

                stepView(number: 2, text: "Enable the Photos Library API for your project.") {
                    openURL(URL(string: "https://console.cloud.google.com/apis/library/photoslibrary.googleapis.com")!)
                }

                stepView(number: 3, text: "Create OAuth 2.0 credentials (Desktop app type).") {
                    openURL(URL(string: "https://console.cloud.google.com/apis/credentials")!)
                }

                stepView(number: 4, text: "Copy Secrets.xcconfig.example to Secrets.xcconfig and paste your Client ID and Client Secret.")

                stepView(number: 5, text: "Rebuild and relaunch the app.")
            }
            .padding(24)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("See the project README for detailed instructions.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func stepView(number: Int, text: String, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body)

                if let action {
                    Button("Open in Browser") {
                        action()
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
        }
    }
}
