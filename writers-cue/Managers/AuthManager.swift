import Foundation
import Supabase
import AuthenticationServices

/// Manages user authentication state and operations
@MainActor
@Observable
class AuthManager {
    static let shared = AuthManager()

    // MARK: - State

    /// Current authentication state
    enum AuthState {
        case unknown      // Initial state, checking stored session
        case signedOut    // No user signed in
        case signedIn     // User is authenticated
    }

    private(set) var state: AuthState = .unknown
    private(set) var currentUser: User?

    /// Whether the user has ever dismissed the sign-in screen
    /// Used to skip showing sign-in on subsequent launches for local-only users
    /// Stored property so SwiftUI can observe changes
    var hasSeenSignIn: Bool = UserDefaults.standard.bool(forKey: "hasSeenSignIn") {
        didSet {
            UserDefaults.standard.set(hasSeenSignIn, forKey: "hasSeenSignIn")
        }
    }

    /// Whether the user has completed onboarding
    /// Set to false to show onboarding on next app launch
    var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        }
    }

    /// Whether the user is currently signed in
    var isSignedIn: Bool {
        state == .signedIn && currentUser != nil
    }

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Check for existing session on app launch
    func checkSession() async {
        do {
            let session = try await supabase.auth.session

            // With emitLocalSessionAsInitialSession enabled, we must check if session is expired
            // An expired session means we need to refresh or sign out
            if session.isExpired {
                // Try to refresh the session
                do {
                    let refreshedSession = try await supabase.auth.refreshSession()
                    currentUser = refreshedSession.user
                    state = .signedIn
                } catch {
                    // Refresh failed, user needs to sign in again
                    currentUser = nil
                    state = .signedOut
                }
            } else {
                currentUser = session.user
                state = .signedIn
            }
        } catch {
            currentUser = nil
            state = .signedOut
        }
    }

    // MARK: - Apple Sign-In

    /// Handle Sign in with Apple credential
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString
            )
        )

        currentUser = session.user
        state = .signedIn
    }

    // MARK: - Google Sign-In

    /// Handle Google Sign-In with ID token
    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )

        currentUser = session.user
        state = .signedIn
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        state = .signedOut
    }

    // MARK: - Account Deletion

    /// Delete the user's account and all cloud data
    func deleteAccount() async throws {
        // First, delete all user data from the database
        try await supabase.rpc("delete_user_data").execute()

        // Note: Full account deletion requires admin API or Edge Function
        // For now, sign out after deleting data
        // The Supabase dashboard or an Edge Function can handle full deletion
        try await signOut()
    }

    // MARK: - Continue Without Account

    /// Mark that user has seen sign-in and chosen to continue without account
    func continueWithoutAccount() {
        hasSeenSignIn = true
        state = .signedOut
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case signInFailed(String)
    case signOutFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        }
    }
}
