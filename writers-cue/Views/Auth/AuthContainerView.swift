import SwiftUI
import SwiftData

/// Container view that handles authentication state and shows either SignInView or the main app
struct AuthContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [WritingProject]

    @State private var showOnboarding = false
    @State private var showSignIn = false
    @State private var hasCheckedAuth = false

    private var authManager: AuthManager { AuthManager.shared }

    var body: some View {
        Group {
            if !hasCheckedAuth {
                // Loading state while checking auth
                ZStack {
                    ThemeManager.shared.colors(for: .light).canvasBackground
                        .ignoresSafeArea()

                    ProgressView()
                }
            } else if showOnboarding {
                OnboardingView(onComplete: {
                    authManager.hasSeenOnboarding = true
                    showOnboarding = false
                    // After onboarding, check if we need to show sign-in
                    if !authManager.isSignedIn && !authManager.hasSeenSignIn {
                        showSignIn = true
                    }
                })
            } else if showSignIn {
                SignInView(
                    onContinueWithoutAccount: {
                        authManager.continueWithoutAccount()
                        showSignIn = false
                    },
                    onSignInComplete: {
                        // Upload existing local projects to cloud
                        Task {
                            await SyncManager.shared.uploadAllProjects(projects)
                        }
                        showSignIn = false
                    }
                )
            } else {
                HomeView()
                    .task {
                        // Pull from cloud on app launch if signed in
                        if authManager.isSignedIn {
                            await SyncManager.shared.appDidBecomeActive(modelContext: modelContext)
                        }
                    }
            }
        }
        .task {
            await checkAuthState()
        }
        .onChange(of: AuthManager.shared.hasSeenSignIn) { _, newValue in
            // When hasSeenSignIn is reset to false (from settings), show sign-in
            if !newValue && !AuthManager.shared.isSignedIn {
                showSignIn = true
            }
        }
        .onChange(of: AuthManager.shared.hasSeenOnboarding) { _, newValue in
            // When hasSeenOnboarding is reset to false (from settings), show onboarding on next check
            if !newValue && hasCheckedAuth {
                showOnboarding = true
            }
        }
    }

    private func checkAuthState() async {
        // Wait for auth manager to check session
        await authManager.checkSession()

        // First check: has user seen onboarding?
        if !authManager.hasSeenOnboarding {
            showOnboarding = true
            hasCheckedAuth = true
            return
        }

        // Determine if we should show sign-in
        if authManager.isSignedIn {
            // User is signed in, go to app
            showSignIn = false
        } else if authManager.hasSeenSignIn {
            // User has previously chosen to continue without account
            showSignIn = false
        } else {
            // First launch or user hasn't made a choice yet
            showSignIn = true
        }

        hasCheckedAuth = true
    }
}

#Preview {
    AuthContainerView()
        .modelContainer(for: WritingProject.self, inMemory: true)
}
