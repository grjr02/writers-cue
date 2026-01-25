import SwiftUI

struct SessionProgressView: View {
    let session: WritingSession
    let currentWordCount: Int
    let onEndSession: () -> Void

    @State private var showingExitConfirmation = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    private var wordsWritten: Int {
        max(0, currentWordCount - session.startingWordCount)
    }

    private var wordProgress: Double {
        min(1.0, Double(wordsWritten) / Double(session.wordCountGoal))
    }

    private var timeProgress: Double? {
        guard let timeGoal = session.timeGoalMinutes else { return nil }
        return min(1.0, elapsedTime / (Double(timeGoal) * 60))
    }

    private var elapsedMinutes: Int {
        Int(elapsedTime / 60)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress ring
            progressRing

            // Stats
            VStack(alignment: .leading, spacing: 2) {
                // Word count
                HStack(spacing: 4) {
                    Text("\(wordsWritten)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("/ \(session.wordCountGoal)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }

                // Time
                Text("\(elapsedMinutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            Spacer()

            // Away reminder indicator
            if session.awayReminderEnabled {
                Image(systemName: "bell.badge")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }

            // End session button
            Button {
                showingExitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .confirmationDialog(
            "End Session?",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                onEndSession()
            }
            Button("Keep Writing", role: .cancel) {}
        } message: {
            Text("You've written \(wordsWritten) of \(session.wordCountGoal) words.")
        }
    }

    private var progressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 4)

            // Progress ring
            Circle()
                .trim(from: 0, to: wordProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: wordProgress)

            // Percentage
            Text("\(Int(wordProgress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .frame(width: 44, height: 44)
    }

    private func startTimer() {
        elapsedTime = Date().timeIntervalSince(session.startTime)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(session.startTime)
        }
    }
}

// MARK: - Exit Confirmation Sheet (Alternative)

struct SessionExitConfirmationView: View {
    let session: WritingSession
    let currentWordCount: Int
    let onBreakFocus: () -> Void
    let onKeepWriting: () -> Void

    private var wordsWritten: Int {
        max(0, currentWordCount - session.startingWordCount)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.orange)
            }
            .padding(.top, 24)

            // Header
            Text("Session in Progress")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            // Progress
            VStack(spacing: 8) {
                Text("Current Progress")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.6))

                HStack(spacing: 4) {
                    Text("\(wordsWritten)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)

                    Text("/ \(session.wordCountGoal)")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    Text("words")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.05))
            )

            // Buttons
            VStack(spacing: 12) {
                Button(action: onKeepWriting) {
                    Text("Keep Writing")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onBreakFocus) {
                    Text("End Session")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.red)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    VStack {
        SessionProgressView(
            session: WritingSession(
                projectId: UUID(),
                wordCountGoal: 500,
                timeGoalMinutes: 30,
                awayReminderEnabled: true,
                awayReminderInterval: .twoMinutes,
                startTime: Date().addingTimeInterval(-300),
                startingWordCount: 100
            ),
            currentWordCount: 250,
            onEndSession: {}
        )
        .padding()

        Spacer()
    }
}
