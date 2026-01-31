import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private var themeManager: ThemeManager { ThemeManager.shared }
    private var authManager: AuthManager { AuthManager.shared }
    private var syncManager: SyncManager { SyncManager.shared }

    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var deleteConfirmationText = ""
    @State private var isProcessing = false
    @State private var showFeedbackSheet = false
    @State private var feedbackCategory: FeedbackCategory = .general
    @State private var feedbackComment = ""
    @State private var feedbackSubmitted = false
    @State private var feedbackError: String?
    @State private var showArchiveSheet = false
    @State private var showPrivacyPolicy = false

    // Get system color scheme directly from UIKit for auto theme
    private var systemColorScheme: ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    // Use explicit color scheme - for auto, detect actual system setting
    private var effectiveColorScheme: ColorScheme {
        themeManager.colorScheme ?? systemColorScheme
    }

    private var panelBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FDFCFA")
    }

    private var inputBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                panelBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Archive section
                        settingsSection(title: "ARCHIVE", icon: "archivebox") {
                            Button {
                                showArchiveSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("View Archived Pieces")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.3))
                                }
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )
                            }
                        }

                        // Theme section
                        settingsSection(title: "THEME", icon: "paintbrush") {
                            HStack(spacing: 10) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    themeButton(theme)
                                }
                            }
                        }

                        // Account section
                        settingsSection(title: "ACCOUNT", icon: "person.circle") {
                            VStack(spacing: 12) {
                                if authManager.isSignedIn {
                                    // Sync status
                                    syncStatusRow

                                    // Sign out button
                                    Button {
                                        showSignOutAlert = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 15, weight: .medium))
                                            Text("Sign Out")
                                                .font(.system(size: 15, weight: .medium))
                                            Spacer()
                                        }
                                        .foregroundStyle(Color.primary.opacity(0.8))
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(inputBackground)
                                        )
                                    }

                                    // Delete account button
                                    Button {
                                        showDeleteAccountAlert = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash")
                                                .font(.system(size: 15, weight: .medium))
                                            Text("Delete Account")
                                                .font(.system(size: 15, weight: .medium))
                                            Spacer()
                                        }
                                        .foregroundStyle(.red)
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(inputBackground)
                                        )
                                    }
                                } else {
                                    // Sign in prompt
                                    signInPrompt
                                }
                            }
                        }

                        // Feedback section
                        settingsSection(title: "FEEDBACK", icon: "bubble.left.and.bubble.right") {
                            Button {
                                showFeedbackSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "paperplane")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Send Feedback")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.3))
                                }
                                .foregroundStyle(Color.primary.opacity(0.8))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )
                            }
                        }

                        // About section
                        settingsSection(title: "ABOUT", icon: "info.circle") {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "hand.wave")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.8))
                                    Text("Show onboarding")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.8))
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { !authManager.hasSeenOnboarding },
                                        set: { authManager.hasSeenOnboarding = !$0 }
                                    ))
                                    .labelsHidden()
                                    .tint(Color(hex: "E4CFBA"))
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )

                                Button {
                                    showPrivacyPolicy = true
                                } label: {
                                    HStack {
                                        Image(systemName: "hand.raised")
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Privacy Policy")
                                            .font(.system(size: 15, weight: .medium))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.primary.opacity(0.3))
                                    }
                                    .foregroundStyle(Color.primary.opacity(0.8))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(inputBackground)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out") {
                    signOut()
                }
            } message: {
                Text("Your projects will remain on this device but won't sync until you sign back in.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    if deleteConfirmationText.uppercased() == "DELETE" {
                        deleteAccount()
                    }
                    deleteConfirmationText = ""
                }
                .disabled(deleteConfirmationText.uppercased() != "DELETE")
            } message: {
                Text("This will permanently delete your cloud backup. Projects on this device will remain. Type DELETE to confirm.")
            }
            .sheet(isPresented: $showFeedbackSheet) {
                feedbackSheet
            }
            .sheet(isPresented: $showArchiveSheet) {
                ArchiveView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Feedback Sent", isPresented: $feedbackSubmitted) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for your feedback!")
            }
            .alert("Error", isPresented: .init(
                get: { feedbackError != nil },
                set: { if !$0 { feedbackError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackError ?? "An error occurred")
            }
        }
        .preferredColorScheme(effectiveColorScheme)
        .id(effectiveColorScheme)
    }

    // MARK: - Sync Status Row

    private var syncStatusRow: some View {
        HStack {
            Image(systemName: syncStatusIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(syncStatusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(syncStatusText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
                if let lastSynced = syncManager.lastSyncedAt {
                    Text("Last synced \(lastSynced.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(inputBackground)
        )
    }

    private var syncStatusIcon: String {
        switch syncManager.status {
        case .idle, .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .error: return "exclamationmark.icloud"
        }
    }

    private var syncStatusColor: Color {
        switch syncManager.status {
        case .idle, .synced: return .green
        case .syncing: return Color(hex: "E4CFBA")
        case .offline: return .orange
        case .error: return .red
        }
    }

    private var syncStatusText: String {
        switch syncManager.status {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .offline: return "Offline"
        case .error: return "Failed to sync"
        }
    }

    // MARK: - Sign In Prompt

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in to back up your work")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text("Your writing will be encrypted and synced to the cloud.")
                .font(.system(size: 13))
                .foregroundStyle(Color.primary.opacity(0.5))

            Button {
                // Reset hasSeenSignIn to show sign in screen
                authManager.hasSeenSignIn = false
                dismiss()
            } label: {
                Text("Sign In")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "E4CFBA"))
                    .cornerRadius(10)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(inputBackground)
        )
    }

    // MARK: - Actions

    private func signOut() {
        isProcessing = true
        Task {
            do {
                try await authManager.signOut()
            } catch {
                print("Sign out error: \(error)")
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func deleteAccount() {
        isProcessing = true
        Task {
            do {
                try await authManager.deleteAccount()
            } catch {
                print("Delete account error: \(error)")
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func submitFeedback() {
        guard !feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            feedbackError = "Please enter a comment"
            return
        }

        isProcessing = true
        Task {
            do {
                try await SupabaseManager.shared.submitFeedback(
                    category: feedbackCategory,
                    comment: feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    isProcessing = false
                    showFeedbackSheet = false
                    feedbackComment = ""
                    feedbackCategory = .general
                    feedbackSubmitted = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    feedbackError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Feedback Sheet

    private var feedbackSheet: some View {
        NavigationStack {
            ZStack {
                panelBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Category selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.6))

                            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                Button {
                                    feedbackCategory = category
                                } label: {
                                    HStack {
                                        Image(systemName: feedbackCategory == category ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(feedbackCategory == category ? Color(hex: "E4CFBA") : Color.primary.opacity(0.3))
                                        Text(category.displayName)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.primary.opacity(0.8))
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(inputBackground)
                                    )
                                }
                            }
                        }

                        // Comment field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.6))

                            TextEditor(text: $feedbackComment)
                                .font(.system(size: 15))
                                .frame(minHeight: 120)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )
                        }

                        // Submit button
                        Button {
                            submitFeedback()
                        } label: {
                            Text("Submit Feedback")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "E4CFBA"))
                                .cornerRadius(12)
                        }
                        .disabled(feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFeedbackSheet = false
                        feedbackComment = ""
                        feedbackCategory = .general
                    }
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
        .id(effectiveColorScheme)
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .tracking(0.8)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func themeButton(_ theme: AppTheme) -> some View {
        let isSelected = themeManager.selectedTheme == theme
        let accentBrown = Color(hex: "E4CFBA")
        return Button {
            themeManager.selectedTheme = theme
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? accentBrown : Color.primary.opacity(0.45))
                Text(theme.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentBrown.opacity(effectiveColorScheme == .dark ? 0.2 : 0.15) : inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentBrown.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    AppSettingsView()
}
