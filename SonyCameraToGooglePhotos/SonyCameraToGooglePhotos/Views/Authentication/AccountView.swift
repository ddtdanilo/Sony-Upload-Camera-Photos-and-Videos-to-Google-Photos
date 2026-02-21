import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            if let name = authViewModel.userName {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            if let email = authViewModel.userEmail {
                Text(email)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(maxWidth: 300)

            Button(role: .destructive) {
                authViewModel.signOut()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
