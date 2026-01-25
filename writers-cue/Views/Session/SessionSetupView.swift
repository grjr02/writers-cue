import SwiftUI

struct SessionSetupView: View {
    let onStart: (Int, Int?, Bool, AwayReminderInterval?, Bool) -> Void
    let onCancel: () -> Void

    @State private var wordCountGoal: Int
    @State private var timeGoalMinutes: Int?
    @State private var useTimeGoal: Bool = false
    @State private var awayReminderEnabled: Bool
    @State private var awayReminderInterval: AwayReminderInterval
    @State private var awayReminderPersistent: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var estimatedMinutes: Int {
        max(1, wordCountGoal / 15)
    }

    private var sessionSummary: String {
        var parts: [String] = []
        parts.append("\(wordCountGoal) words")

        if let time = timeGoalMinutes, useTimeGoal {
            parts.append("\(time) min")
        }

        if awayReminderEnabled {
            parts.append("Reminder: \(awayReminderInterval.displayName)")
        }

        if !useTimeGoal {
            parts.append("~\(estimatedMinutes) min")
        }

        return parts.joined(separator: " • ")
    }

    init(
        settings: SessionSettings,
        onStart: @escaping (Int, Int?, Bool, AwayReminderInterval?, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCancel = onCancel
        _wordCountGoal = State(initialValue: settings.lastWordCountGoal)
        _timeGoalMinutes = State(initialValue: settings.lastTimeGoalMinutes)
        _useTimeGoal = State(initialValue: settings.lastTimeGoalMinutes != nil)
        _awayReminderEnabled = State(initialValue: settings.lastAwayReminderEnabled)
        _awayReminderInterval = State(initialValue: settings.lastAwayReminderInterval)
        _awayReminderPersistent = State(initialValue: settings.lastAwayReminderPersistent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Presets
                    presetsSection

                    // Word Count Goal
                    wordCountSection

                    // Time Goal (Optional)
                    timeGoalSection

                    // Away Reminder
                    awayReminderSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7"))
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
            }
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Quick Presets")

            HStack(spacing: 10) {
                ForEach(SessionGoalPreset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: SessionGoalPreset) -> some View {
        let isSelected = wordCountGoal == preset.wordCount

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                wordCountGoal = preset.wordCount
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20, weight: .medium))

                Text(preset.displayName)
                    .font(.system(size: 13, weight: .medium))

                Text("\(preset.wordCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor : cardBackground)
            )
            .foregroundStyle(isSelected ? .white : Color.primary)
        }
    }

    // MARK: - Word Count Section

    private var wordCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Word Count Goal")

            VStack(spacing: 16) {
                HStack {
                    Text("Write")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary.opacity(0.7))

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("", value: $wordCountGoal, format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)

                        Text("words")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }

                // Slider
                Slider(value: Binding(
                    get: { Double(wordCountGoal) },
                    set: { wordCountGoal = Int($0) }
                ), in: 50...2000, step: 50)
                .tint(Color.accentColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
        }
    }

    // MARK: - Time Goal Section

    private var timeGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Time Goal (Optional)")

            VStack(spacing: 0) {
                Toggle(isOn: $useTimeGoal.animation(.spring(response: 0.3))) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.accentColor)

                        Text("Set time goal")
                            .font(.system(size: 16))
                    }
                }
                .tint(Color.accentColor)
                .padding(16)

                if useTimeGoal {
                    Divider()
                        .padding(.leading, 16)

                    HStack {
                        Text("Write for")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary.opacity(0.7))

                        Spacer()

                        HStack(spacing: 4) {
                            TextField("", value: Binding(
                                get: { timeGoalMinutes ?? 15 },
                                set: { timeGoalMinutes = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)

                            Text("min")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primary.opacity(0.7))
                        }
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
        }
    }

    // MARK: - Away Reminder Section

    private var awayReminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Away Reminder")

            VStack(spacing: 0) {
                Toggle(isOn: $awayReminderEnabled.animation(.spring(response: 0.3))) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.accentColor)

                            Text("Remind me to come back")
                                .font(.system(size: 16))
                        }

                        Text("Get a notification if you leave during a session")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                }
                .tint(Color.accentColor)
                .padding(16)

                if awayReminderEnabled {
                    Divider()
                        .padding(.leading, 16)

                    VStack(spacing: 8) {
                        ForEach(AwayReminderInterval.allCases, id: \.self) { interval in
                            awayReminderIntervalRow(interval)
                        }
                    }
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    Divider()
                        .padding(.leading, 16)

                    Toggle(isOn: $awayReminderPersistent.animation(.spring(response: 0.3))) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.accentColor)

                                Text("Persistent")
                                    .font(.system(size: 16))
                            }

                            Text("Send up to 3 reminders at \(awayReminderInterval.rawValue), \(awayReminderInterval.rawValue * 2), \(awayReminderInterval.rawValue * 3) min")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                    .tint(Color.accentColor)
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
        }
    }

    private func awayReminderIntervalRow(_ interval: AwayReminderInterval) -> some View {
        let isSelected = awayReminderInterval == interval

        return Button {
            withAnimation(.spring(response: 0.2)) {
                awayReminderInterval = interval
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.5))
                    .frame(width: 24)

                Text(interval.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: 8) {
            // Summary
            Text(sessionSummary)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary.opacity(0.6))

            // Button
            Button {
                onStart(
                    wordCountGoal,
                    useTimeGoal ? timeGoalMinutes : nil,
                    awayReminderEnabled,
                    awayReminderEnabled ? awayReminderInterval : nil,
                    awayReminderEnabled ? awayReminderPersistent : false
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Start Writing")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.5))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
    }
}

#Preview {
    SessionSetupView(
        settings: .defaultSettings,
        onStart: { _, _, _, _, _ in },
        onCancel: {}
    )
}
