import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Sony Camera → Google Photos")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Upload photos and videos from your Sony camera\ndirectly to Google Photos")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                authViewModel.signIn()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                    Text("Sign in with Google")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authViewModel.isLoading)

            if authViewModel.isLoading {
                ProgressView("Signing in...")
            }

            if let error = authViewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
