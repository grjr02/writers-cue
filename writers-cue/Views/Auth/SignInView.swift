import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showError = false

    let onContinueWithoutAccount: () -> Void
    let onSignInComplete: () -> Void

    private var themeManager: ThemeManager { ThemeManager.shared }

    private var currentColors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color(hex: "9A9A9A") : Color(hex: "6B6B6B")
    }

    var body: some View {
        ZStack {
            currentColors.canvasBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App title and tagline
                VStack(spacing: 12) {
                    Text("Writer's Cue")
                        .font(.system(size: 32, weight: .bold))

                    Text("Back up your writing to the cloud.\nNever lose your work again.")
                        .font(.system(size: 17))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Sign in with Apple
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.email]
                    },
                    onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .disabled(isSigningIn)

                // Continue without account
                Button {
                    onContinueWithoutAccount()
                } label: {
                    Text("Continue without account")
                        .font(.system(size: 15))
                        .foregroundStyle(subtitleColor)
                        .padding(.vertical, 16)
                }
                .padding(.top, 8)

                // Footer note
                Text("Your writing is encrypted and only you can read it.")
                    .font(.system(size: 13))
                    .foregroundStyle(subtitleColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }

            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential type"
                showError = true
                return
            }

            isSigningIn = true

            Task {
                do {
                    try await AuthManager.shared.signInWithApple(credential: credential)
                    await MainActor.run {
                        isSigningIn = false
                        onSignInComplete()
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

        case .failure(let error):
            // User cancelled is not an error to show
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

}

#Preview {
    SignInView(
        onContinueWithoutAccount: {},
        onSignInComplete: {}
    )
}
