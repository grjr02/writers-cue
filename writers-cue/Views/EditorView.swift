import SwiftUI
import SwiftData
import UIKit

struct EditorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: WritingProject

    @State private var sessionManager = SessionManager()
    @State private var showingShareSheet = false
    @State private var showingSettings = false
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isKeyboardVisible = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var editorController = RichTextEditorController()
    private var themeManager: ThemeManager { ThemeManager.shared }

    // Writing Session Flow
    private var writingSessionManager: WritingSessionManager { WritingSessionManager.shared }
    @State private var showSessionSetup = false
    @State private var showSessionCompletion = false
    @State private var showEndSessionConfirmation = false
    @State private var showFlash = false

    // Formatting state
    @State private var formattingState = FormattingState()

    @FocusState private var isEditorFocused: Bool

    private var hasSelection: Bool {
        selectedRange.length > 0
    }

    private var currentColors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }

    private var currentWordCount: Int {
        project.wordCount
    }

    // Session state helpers
    private var hasActiveSession: Bool {
        guard let session = writingSessionManager.currentSession else { return false }
        return !session.isCompleted && session.projectId == project.id
    }

    private var hasCompletedSession: Bool {
        guard let session = writingSessionManager.currentSession else { return false }
        return session.isCompleted && session.projectId == project.id
    }

    private var sessionGoalReached: Bool {
        writingSessionManager.currentSession?.goalReached ?? false
    }

    var body: some View {
        ZStack {
            // Background color
            currentColors.canvasBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                RichTextEditor(
                    attributedText: $attributedText,
                    selectedRange: $selectedRange,
                    onTextChange: handleTextChange,
                    onKeyboardChange: { visible, height in
                        isKeyboardVisible = visible
                        keyboardHeight = height
                    },
                    controller: editorController,
                    textColor: currentColors.uiTextColor,
                    tintColor: currentColors.uiAccentColor,
                    isDarkMode: colorScheme == .dark
                )
                .focused($isEditorFocused)
            }
            .ignoresSafeArea(.keyboard)

            // Floating toolbar - positioned just above keyboard on the right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FormattingToolbar(
                        onBold: applyBold,
                        onItalic: applyItalic,
                        onUnderline: applyUnderline,
                        onTitle: { applyStyle(.title) },
                        onHeading: { applyStyle(.heading) },
                        onSubheading: { applyStyle(.subheading) },
                        onBody: { applyStyle(.body) },
                        onToggleKeyboard: toggleKeyboard,
                        isKeyboardVisible: isKeyboardVisible,
                        isBoldActive: formattingState.isBold,
                        isItalicActive: formattingState.isItalic,
                        isUnderlineActive: formattingState.isUnderline,
                        currentStyle: formattingState.currentStyle
                    )
                    .padding(.trailing, 12)
                }
            }
            .padding(.bottom, keyboardHeight + 2)
            .ignoresSafeArea(.keyboard)
            .animation(.spring(response: 0.3), value: keyboardHeight)

            // Flash overlay for goal completion
            if showFlash {
                Color.green.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Session button - always visible, different states
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    if hasCompletedSession {
                        // Show completed session results
                        showSessionCompletion = true
                    } else if hasActiveSession {
                        showEndSessionConfirmation = true
                    } else {
                        showSessionSetup = true
                    }
                } label: {
                    Image(systemName: hasCompletedSession ? "checkmark.circle.fill" : (hasActiveSession ? "target" : "target"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(hasCompletedSession ? .green : (hasActiveSession ? .accentColor : .secondary))
                }
            }

            // Settings button
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .navigationBarHidden(showingSettings)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [project.plainTextContent])
        }
        .overlay {
            SettingsSidePanel(
                isPresented: $showingSettings,
                documentTitle: Binding(
                    get: { project.title },
                    set: { project.title = $0 }
                ),
                maxInactivityHours: Binding(
                    get: { project.maxInactivityHours },
                    set: { newValue in
                        project.maxInactivityHours = newValue
                        NotificationManager.shared.scheduleNudgeNotification(for: project)
                    }
                ),
                nudgeMode: Binding(
                    get: { project.nudgeMode },
                    set: { newValue in
                        project.nudgeMode = newValue
                        NotificationManager.shared.scheduleNudgeNotification(for: project)
                    }
                ),
                nudgeHour: Binding(
                    get: { project.nudgeHour },
                    set: { newValue in
                        project.nudgeHour = newValue
                        NotificationManager.shared.scheduleNudgeNotification(for: project)
                    }
                ),
                nudgeMinute: Binding(
                    get: { project.nudgeMinute },
                    set: { newValue in
                        project.nudgeMinute = newValue
                        NotificationManager.shared.scheduleNudgeNotification(for: project)
                    }
                ),
                nudgeEnabled: Binding(
                    get: { project.nudgeEnabled },
                    set: { newValue in
                        project.nudgeEnabled = newValue
                        if newValue {
                            NotificationManager.shared.scheduleNudgeNotification(for: project)
                        } else {
                            NotificationManager.shared.cancelNudgeNotification(for: project.id)
                        }
                    }
                ),
                onShare: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSettings = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingShareSheet = true
                    }
                },
                onArchive: {
                    archiveProject()
                }
            )
        }
        .sheet(isPresented: $showSessionSetup) {
            SessionSetupView(
                settings: writingSessionManager.settings,
                onStart: { wordGoal, timeGoal, awayReminderEnabled, awayReminderInterval, awayReminderPersistent in
                    writingSessionManager.startSession(
                        projectId: project.id,
                        wordCountGoal: wordGoal,
                        timeGoalMinutes: timeGoal,
                        awayReminderEnabled: awayReminderEnabled,
                        awayReminderInterval: awayReminderInterval,
                        awayReminderPersistent: awayReminderPersistent,
                        startingWordCount: currentWordCount
                    )
                    showSessionSetup = false
                },
                onCancel: {
                    showSessionSetup = false
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSessionCompletion) {
            if let session = writingSessionManager.currentSession {
                SessionCompletionView(
                    session: session,
                    onSetAnotherGoal: {
                        writingSessionManager.clearCompletedSession()
                        showSessionCompletion = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSessionSetup = true
                        }
                    },
                    onContinueWriting: {
                        writingSessionManager.clearCompletedSession()
                        showSessionCompletion = false
                    },
                    onSaveAndClose: {
                        writingSessionManager.clearCompletedSession()
                        showSessionCompletion = false
                        dismiss()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .alert("End session?", isPresented: $showEndSessionConfirmation) {
            Button("Keep writing", role: .cancel) { }
            Button("End session", role: .destructive) {
                writingSessionManager.completeSession(finalWordCount: currentWordCount)
                showSessionCompletion = true
            }
        } message: {
            if sessionGoalReached {
                Text("Great work! Ready to wrap up?")
            } else {
                Text("You're making progress. Are you sure you want to stop?")
            }
        }
        .onAppear {
            attributedText = project.attributedContent
            sessionManager.startSession(with: project.plainTextContent)

            // Set up formatting change callback
            editorController.onFormattingChange = { state in
                formattingState = state
            }

            // Set initial typing style to Title (H1) for empty documents
            if attributedText.length == 0 {
                editorController.setStyleForTyping(.title, isDarkMode: colorScheme == .dark)
                formattingState.currentStyle = .title
            }

            // Cancel any pending away reminder when returning to editor
            writingSessionManager.cancelAwayReminder()
        }
        .onDisappear {
            endSessionAndScheduleNotification()

            // Sync to cloud when leaving editor
            SyncManager.shared.editorWillDisappear(project: project)

            // Schedule away reminder if leaving during an active writing session
            if writingSessionManager.isSessionActive,
               writingSessionManager.currentSession?.projectId == project.id {
                writingSessionManager.scheduleAwayReminder()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                endSessionAndScheduleNotification()

                // Schedule away reminder if there's an active writing session
                if writingSessionManager.isSessionActive,
                   writingSessionManager.currentSession?.projectId == project.id {
                    writingSessionManager.scheduleAwayReminder()
                }
            } else if newPhase == .active {
                // Cancel away reminder when returning
                writingSessionManager.cancelAwayReminder()

                if !sessionManager.isSessionActive {
                    sessionManager.startSession(with: project.plainTextContent)
                }
            }
        }
    }

    // MARK: - Text Handling

    private func handleTextChange() {
        project.attributedContent = attributedText
        project.lastEditedAt = Date()
        sessionManager.updateContent(project.plainTextContent)

        // Trigger cloud sync (debounced)
        SyncManager.shared.contentDidChange(project: project)

        // Check writing session goal progress
        checkSessionProgress()
    }

    private func checkSessionProgress() {
        guard let session = writingSessionManager.currentSession,
              !session.isCompleted,
              session.projectId == project.id else {
            return
        }

        let wordsWritten = currentWordCount - session.startingWordCount

        // Check if word goal is met - auto-end session silently
        if wordsWritten >= session.wordCountGoal && !session.goalReached {
            // Trigger celebration
            triggerGoalCelebration()

            // Complete the session silently - user can tap session button to see results
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.writingSessionManager.completeSession(finalWordCount: self.currentWordCount)
                // Don't show modal - let user continue writing uninterrupted
            }
        }
    }

    private func triggerGoalCelebration() {
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

        // Success haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }

    // MARK: - Formatting Actions

    private func applyBold() {
        if hasSelection {
            attributedText = TextFormatter.toggleBold(in: attributedText, range: selectedRange)
            project.attributedContent = attributedText
            editorController.notifyFormattingChange()
        } else {
            editorController.toggleBoldTyping()
        }
    }

    private func applyItalic() {
        if hasSelection {
            attributedText = TextFormatter.toggleItalic(in: attributedText, range: selectedRange)
            project.attributedContent = attributedText
            editorController.notifyFormattingChange()
        } else {
            editorController.toggleItalicTyping()
        }
    }

    private func applyUnderline() {
        if hasSelection {
            attributedText = TextFormatter.toggleUnderline(in: attributedText, range: selectedRange)
            project.attributedContent = attributedText
            editorController.notifyFormattingChange()
        } else {
            editorController.toggleUnderlineTyping()
        }
    }

    private func applyStyle(_ style: TextStyle) {
        let isDark = colorScheme == .dark
        TextFormatter.isDarkMode = isDark

        // Check if we should apply the style to existing text
        var shouldApplyToExistingText = hasSelection

        if !shouldApplyToExistingText && attributedText.length > 0 {
            let string = attributedText.string as NSString

            // Check if cursor is at the start of a new/empty line
            // (right after a newline or at position 0)
            let atStartOfLine: Bool
            if selectedRange.location == 0 {
                atStartOfLine = true
            } else if selectedRange.location <= string.length && selectedRange.location > 0 {
                atStartOfLine = string.character(at: selectedRange.location - 1) == 0x0A // newline
            } else {
                atStartOfLine = true // cursor beyond end
            }

            // Check if current line is empty (no content after cursor until next newline or end)
            let lineIsEmpty: Bool
            if atStartOfLine {
                if selectedRange.location >= string.length {
                    lineIsEmpty = true
                } else {
                    let charAtCursor = string.character(at: selectedRange.location)
                    lineIsEmpty = charAtCursor == 0x0A // next char is also newline
                }
            } else {
                lineIsEmpty = false
            }

            // Only apply to existing text if we're NOT on an empty new line
            shouldApplyToExistingText = !(atStartOfLine && lineIsEmpty)
        }

        if shouldApplyToExistingText {
            // Apply style to selected text or current line
            attributedText = TextFormatter.applyStyle(style, in: attributedText, range: selectedRange)
            project.attributedContent = attributedText
        }

        // Always set typing attributes so next typed text uses this style
        editorController.setStyleForTyping(style, isDarkMode: isDark)
    }

    // MARK: - Keyboard

    private func toggleKeyboard() {
        if isKeyboardVisible {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            isEditorFocused = true
        }
    }

    // MARK: - Session

    private func endSessionAndScheduleNotification() {
        let result = sessionManager.endSession()

        if result.countsAsProgress {
            project.lastProgressAt = Date()
            NotificationManager.shared.scheduleInactivityNotification(for: project)
        }
    }

    // MARK: - Archive

    private func archiveProject() {
        // Close the settings panel first
        withAnimation(.easeInOut(duration: 0.25)) {
            showingSettings = false
        }

        // Cancel notifications for archived projects
        NotificationManager.shared.cancelAllNotifications(for: project.id)

        // Archive the project
        project.isArchived = true
        project.needsSync = true

        // Sync to cloud
        Task {
            await SyncManager.shared.uploadProject(project)
        }

        // Navigate back to home after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        EditorView(
            project: WritingProject(
                title: "Sample Article",
                deadline: Date().addingTimeInterval(7 * 24 * 3600),
                maxInactivityHours: 48
            )
        )
    }
    .modelContainer(for: WritingProject.self, inMemory: true)
}
