import Foundation
import SwiftUI

// MARK: - Away Reminder Interval

enum AwayReminderInterval: Int, CaseIterable, Codable {
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15

    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .twoMinutes: return "2 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

// MARK: - Session Goal Preset

enum SessionGoalPreset: String, CaseIterable {
    case quick
    case standard
    case deepWork

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .deepWork: return "Deep Work"
        }
    }

    var wordCount: Int {
        switch self {
        case .quick: return 150
        case .standard: return 500
        case .deepWork: return 1000
        }
    }

    var icon: String {
        switch self {
        case .quick: return "hare.fill"
        case .standard: return "pencil.line"
        case .deepWork: return "brain.head.profile"
        }
    }
}

// MARK: - Writing Session

struct WritingSession: Codable {
    var id: UUID = UUID()
    var projectId: UUID
    var wordCountGoal: Int
    var timeGoalMinutes: Int?
    var awayReminderEnabled: Bool
    var awayReminderInterval: AwayReminderInterval?
    var awayReminderPersistent: Bool = false
    var startTime: Date
    var startingWordCount: Int
    var isCompleted: Bool = false
    var goalReached: Bool = false  // Goal met but session continues
    var goalReachedAt: Date?
    var completedAt: Date?
    var finalWordCount: Int?

    var wordsWritten: Int {
        (finalWordCount ?? 0) - startingWordCount
    }

    var elapsedMinutes: Int {
        let endTime = completedAt ?? Date()
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var estimatedMinutes: Int {
        // Assuming ~15 words per minute
        return max(1, wordCountGoal / 15)
    }
}

// MARK: - Session Settings (Persisted)

struct SessionSettings: Codable {
    var lastWordCountGoal: Int = 300
    var lastTimeGoalMinutes: Int?
    var lastAwayReminderEnabled: Bool = true
    var lastAwayReminderInterval: AwayReminderInterval = .twoMinutes
    var lastAwayReminderPersistent: Bool = false

    static let defaultSettings = SessionSettings()
}

// MARK: - Writing Session Manager

@Observable
class WritingSessionManager {
    static let shared = WritingSessionManager()

    var currentSession: WritingSession?
    var settings: SessionSettings

    var isSessionActive: Bool {
        currentSession != nil && !(currentSession?.isCompleted ?? true)
    }

    private let settingsKey = "writingSessionSettings"
    private let activeSessionKey = "activeWritingSession"
    static let awayNotificationIdentifier = "writingSessionAwayReminder"

    private init() {
        // Load settings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(SessionSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .defaultSettings
        }

        // Restore active session if app was closed
        if let data = UserDefaults.standard.data(forKey: activeSessionKey),
           let decoded = try? JSONDecoder().decode(WritingSession.self, from: data) {
            if !decoded.isCompleted {
                self.currentSession = decoded
            }
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func startSession(
        projectId: UUID,
        wordCountGoal: Int,
        timeGoalMinutes: Int?,
        awayReminderEnabled: Bool,
        awayReminderInterval: AwayReminderInterval?,
        awayReminderPersistent: Bool,
        startingWordCount: Int
    ) {
        let session = WritingSession(
            projectId: projectId,
            wordCountGoal: wordCountGoal,
            timeGoalMinutes: timeGoalMinutes,
            awayReminderEnabled: awayReminderEnabled,
            awayReminderInterval: awayReminderInterval,
            awayReminderPersistent: awayReminderPersistent,
            startTime: Date(),
            startingWordCount: startingWordCount
        )

        currentSession = session
        persistActiveSession()

        // Update settings for next time
        settings.lastWordCountGoal = wordCountGoal
        settings.lastTimeGoalMinutes = timeGoalMinutes
        settings.lastAwayReminderEnabled = awayReminderEnabled
        if let interval = awayReminderInterval {
            settings.lastAwayReminderInterval = interval
        }
        settings.lastAwayReminderPersistent = awayReminderPersistent
        saveSettings()
    }

    func updateProgress(currentWordCount: Int) {
        guard let session = currentSession, !session.isCompleted else { return }

        let wordsWritten = currentWordCount - session.startingWordCount

        // Check if word goal is met
        if wordsWritten >= session.wordCountGoal {
            completeSession(finalWordCount: currentWordCount)
        }
    }

    func checkTimeGoal() -> Bool {
        guard let session = currentSession,
              let timeGoal = session.timeGoalMinutes,
              !session.isCompleted else {
            return false
        }

        let elapsed = Int(Date().timeIntervalSince(session.startTime) / 60)
        return elapsed >= timeGoal
    }

    /// Mark the goal as reached without ending the session
    /// Returns true if this is the first time the goal was reached (for showing confetti)
    func markGoalReached() -> Bool {
        guard var session = currentSession,
              !session.isCompleted,
              !session.goalReached else {
            return false
        }

        session.goalReached = true
        session.goalReachedAt = Date()
        currentSession = session
        persistActiveSession()
        return true
    }

    func completeSession(finalWordCount: Int) {
        guard var session = currentSession else { return }

        session.isCompleted = true
        session.completedAt = Date()
        session.finalWordCount = finalWordCount
        currentSession = session

        // Cancel any pending away reminder
        cancelAwayReminder()

        // Clear persisted active session
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
    }

    func cancelSession() {
        cancelAwayReminder()
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
    }

    func clearCompletedSession() {
        if currentSession?.isCompleted == true {
            currentSession = nil
        }
    }

    private func persistActiveSession() {
        if let session = currentSession,
           let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: activeSessionKey)
        }
    }

    // MARK: - Away Reminder Notifications

    func scheduleAwayReminder() {
        guard let session = currentSession,
              !session.isCompleted,
              session.awayReminderEnabled,
              let interval = session.awayReminderInterval else {
            return
        }

        let wordsRemaining = session.wordCountGoal - (session.finalWordCount ?? session.startingWordCount) + session.startingWordCount

        // Determine how many notifications to schedule
        let notificationCount = session.awayReminderPersistent ? 3 : 1

        for i in 1...notificationCount {
            let content = UNMutableNotificationContent()
            content.sound = .default

            if i == 1 {
                content.title = "Come back to your writing!"
                content.body = "You have an active writing session. \(wordsRemaining) words to go!"
            } else if i == 2 {
                content.title = "Still waiting for you!"
                content.body = "Your writing session is still active. Don't give up now!"
            } else {
                content.title = "Last reminder!"
                content.body = "Your writing goal is waiting. Just a few words can make a difference!"
            }

            // Schedule at 1x, 2x, 3x the interval
            let triggerTime = interval.seconds * Double(i)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: triggerTime,
                repeats: false
            )

            let identifier = "\(Self.awayNotificationIdentifier)_\(i)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule away reminder \(i): \(error)")
                } else {
                    let minutes = Int(triggerTime / 60)
                    print("Away reminder \(i) scheduled for \(minutes) minute(s)")
                }
            }
        }
    }

    func cancelAwayReminder() {
        // Cancel all possible reminder notifications (1, 2, and 3)
        let identifiers = (1...3).map { "\(Self.awayNotificationIdentifier)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }
}
