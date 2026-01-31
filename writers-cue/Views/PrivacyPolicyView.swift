import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var panelBackground: Color {
        colorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FDFCFA")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                panelBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Last updated: January 27, 2025")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primary.opacity(0.5))

                        policySection(
                            title: "Overview",
                            body: "Writer's Cue is a writing app designed to help you stay on track with your writing projects. Your privacy matters to us. This policy explains what data we collect, how we use it, and the choices you have."
                        )

                        policySection(
                            title: "Data We Collect",
                            body: """
                            Local-Only Use (No Account)
                            If you use Writer's Cue without creating an account, all of your data stays on your device. We do not collect, transmit, or have access to any of your writing, settings, or usage data.

                            With an Account (Cloud Backup)
                            If you choose to sign in with Apple or Google, we collect:
                            \u{2022} Your authentication credentials (managed by Apple/Google and Supabase)
                            \u{2022} Your writing projects, including titles and content, for the purpose of cloud backup and sync
                            \u{2022} Project metadata such as creation dates, last edited timestamps, and nudge settings

                            Your writing content is encrypted on your device before being uploaded. We cannot read your writing.
                            """
                        )

                        policySection(
                            title: "How We Use Your Data",
                            body: """
                            \u{2022} To store and sync your writing projects across your devices
                            \u{2022} To restore your projects if you delete and reinstall the app
                            \u{2022} To provide nudge notifications based on your configured settings
                            \u{2022} To process feedback you voluntarily submit
                            """
                        )

                        policySection(
                            title: "Third-Party Services",
                            body: """
                            Writer's Cue uses the following third-party services:

                            \u{2022} Supabase — for authentication and encrypted cloud storage
                            \u{2022} Apple Sign-In — for account authentication
                            \u{2022} Google Sign-In — for account authentication

                            These services have their own privacy policies. We encourage you to review them.
                            """
                        )

                        policySection(
                            title: "Data Encryption",
                            body: "All writing content is encrypted on your device using AES-256-GCM before being sent to our servers. This means that even in the event of a data breach, your writing cannot be read by anyone other than you."
                        )

                        policySection(
                            title: "Data Retention & Deletion",
                            body: """
                            \u{2022} Your data is stored as long as you maintain an account.
                            \u{2022} You can delete your account at any time from Settings. This permanently removes all of your data from our servers.
                            \u{2022} Local data on your device is not affected by account deletion.
                            \u{2022} If you use the app without an account, no data is ever sent to our servers.
                            """
                        )

                        policySection(
                            title: "Children's Privacy",
                            body: "Writer's Cue is not directed at children under 13. We do not knowingly collect personal information from children under 13."
                        )

                        policySection(
                            title: "Changes to This Policy",
                            body: "We may update this privacy policy from time to time. We will notify you of any changes by updating the date at the top of this policy."
                        )

                        policySection(
                            title: "Contact",
                            body: "If you have questions about this privacy policy, please reach out to us through the Send Feedback option in Settings."
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.9))
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineSpacing(4)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
