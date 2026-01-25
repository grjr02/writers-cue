import SwiftUI

struct SessionCompletionView: View {
    let session: WritingSession
    let onSetAnotherGoal: () -> Void
    let onContinueWriting: () -> Void
    let onSaveAndClose: () -> Void

    @State private var showContent = false
    @State private var showFlash = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
                .ignoresSafeArea()

            // Subtle flash effect
            if showFlash {
                Color.green.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Content
            VStack(spacing: 16) {
                // Celebration icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .scaleEffect(showContent ? 1 : 0.5)
                        .opacity(showContent ? 1 : 0)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.green)
                        .scaleEffect(showContent ? 1 : 0)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showContent)
                .padding(.top, 24)

                // Header
                VStack(spacing: 4) {
                    Text("Goal Complete!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.4), value: showContent)

                    Text("Amazing work!")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.5), value: showContent)
                }

                // Stats card
                statsCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    .animation(.spring(response: 0.5).delay(0.6), value: showContent)

                Spacer()

                // Action buttons
                VStack(spacing: 10) {
                    Button(action: onSetAnotherGoal) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .medium))
                            Text("Set Another Goal")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onContinueWriting) {
                        Text("Continue Writing")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            )
                    }

                    Button(action: onSaveAndClose) {
                        Text("Save & Close")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.6))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 40)
                .animation(.spring(response: 0.5).delay(0.8), value: showContent)
            }
        }
        .onAppear {
            triggerCelebration()
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            // Words written
            statItem(
                value: "\(session.wordsWritten)",
                label: "Words",
                icon: "text.word.spacing"
            )

            Divider()
                .frame(height: 36)

            // Time taken
            statItem(
                value: "\(session.elapsedMinutes)",
                label: "Minutes",
                icon: "clock"
            )

            Divider()
                .frame(height: 36)

            // Words per minute
            statItem(
                value: "\(wordsPerMinute)",
                label: "WPM",
                icon: "speedometer"
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "F2F2F7"))
        )
        .padding(.horizontal, 24)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var wordsPerMinute: Int {
        guard session.elapsedMinutes > 0 else { return 0 }
        return session.wordsWritten / session.elapsedMinutes
    }

    private func triggerCelebration() {
        // Trigger haptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Show flash
        withAnimation(.easeIn(duration: 0.15)) {
            showFlash = true
        }

        // Fade out flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFlash = false
            }
        }

        // Show content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showContent = true
        }

        // Success haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
}

#Preview {
    SessionCompletionView(
        session: WritingSession(
            projectId: UUID(),
            wordCountGoal: 300,
            timeGoalMinutes: nil,
            awayReminderEnabled: true,
            awayReminderInterval: .twoMinutes,
            startTime: Date().addingTimeInterval(-1200),
            startingWordCount: 50,
            isCompleted: true,
            completedAt: Date(),
            finalWordCount: 380
        ),
        onSetAnotherGoal: {},
        onContinueWriting: {},
        onSaveAndClose: {}
    )
}
