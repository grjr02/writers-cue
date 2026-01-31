import Foundation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Notification category identifiers
    private let nudgeCategoryIdentifier = "NUDGE_CATEGORY"
    private let snoozeActionIdentifier = "SNOOZE_ACTION"

    // Randomized nudge messages
    private let nudgeMessages = [
        "Your story is waiting. Time to write!",
        "A few words today keeps writer's block away.",
        "Your thoughts miss you. Time to continue writing.",
        "Every great writing is written one session at a time.",
        "You words is calling. Ready to fill it?",
        // "Your writing streak is waiting to continue.",
        "Just 10 minutes of writing can make a difference.",
        "Time to put pen to paper (or fingers to keys).",
        "Your words matter. Let's keep going.",
        "The muse is knocking. Time to write!"
    ]

    private override init() {
        super.init()
        setupNotificationCategories()
    }

    // MARK: - Setup

    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Remind me in 1 hour",
            options: []
        )

        let nudgeCategory = UNNotificationCategory(
            identifier: nudgeCategoryIdentifier,
            actions: [snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([nudgeCategory])
    }

    // MARK: - Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = self
    }

    // MARK: - Nudge Notifications

    /// Schedules a nudge notification based on the project's nudge settings
    func scheduleNudgeNotification(for project: WritingProject) {
        cancelNudgeNotification(for: project.id)

        // Don't schedule if nudges are disabled
        guard project.nudgeEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = project.title
        content.body = nudgeMessages.randomElement() ?? nudgeMessages[0]
        content.sound = .default
        content.categoryIdentifier = nudgeCategoryIdentifier
        content.userInfo = ["projectId": project.id.uuidString, "projectTitle": project.title]

        switch project.nudgeMode {
        case .afterInactivity:
            scheduleInactivityNudge(for: project, content: content)
        case .daily:
            scheduleDailyNudge(for: project, content: content)
        }
    }

    /// Schedules nudge at preferred time AFTER inactivity threshold passes
    private func scheduleInactivityNudge(for project: WritingProject, content: UNMutableNotificationContent) {
        // Calculate when inactivity threshold is met
        let lastActivity = project.lastProgressAt ?? project.lastEditedAt
        let inactivityThreshold = lastActivity.addingTimeInterval(TimeInterval(project.maxInactivityHours * 3600))

        // Find the first occurrence of preferred time AFTER the inactivity threshold
        let calendar = Calendar.current
        var preferredComponents = DateComponents()
        preferredComponents.hour = project.nudgeHour
        preferredComponents.minute = project.nudgeMinute

        // Start from inactivity threshold and find next occurrence of preferred time
        var triggerDate: Date?

        if inactivityThreshold <= Date() {
            // Inactivity already passed, find next preferred time from now
            triggerDate = calendar.nextDate(after: Date(), matching: preferredComponents, matchingPolicy: .nextTime)
        } else {
            // Find next preferred time after the inactivity threshold
            triggerDate = calendar.nextDate(after: inactivityThreshold, matching: preferredComponents, matchingPolicy: .nextTime)

            // If the preferred time occurs on the same day as inactivity threshold but before it,
            // we need the next day's occurrence
            if let trigger = triggerDate, trigger < inactivityThreshold {
                triggerDate = calendar.nextDate(after: trigger, matching: preferredComponents, matchingPolicy: .nextTime)
            }
        }

        guard let finalTriggerDate = triggerDate, finalTriggerDate > Date() else { return }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: finalTriggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: nudgeIdentifier(for: project.id),
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// Schedules a daily repeating nudge at the preferred time
    private func scheduleDailyNudge(for project: WritingProject, content: UNMutableNotificationContent) {
        var components = DateComponents()
        components.hour = project.nudgeHour
        components.minute = project.nudgeMinute

        // Repeating daily trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: nudgeIdentifier(for: project.id),
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelNudgeNotification(for projectId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [nudgeIdentifier(for: projectId)])
    }

    // Legacy method for backward compatibility
    func scheduleInactivityNotification(for project: WritingProject) {
        scheduleNudgeNotification(for: project)
    }

    func cancelInactivityNotification(for projectId: UUID) {
        cancelNudgeNotification(for: projectId)
    }

    // MARK: - Snooze Notification

    private func scheduleSnoozeNotification(projectId: String, projectTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = projectTitle
        content.body = nudgeMessages.randomElement() ?? nudgeMessages[0]
        content.sound = .default
        content.categoryIdentifier = nudgeCategoryIdentifier
        content.userInfo = ["projectId": projectId, "projectTitle": projectTitle]

        // 1 hour from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)

        let request = UNNotificationRequest(
            identifier: "snooze-\(projectId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Deadline Notifications

    func scheduleDeadlineNotifications(for project: WritingProject) {
        cancelDeadlineNotifications(for: project.id)

        // 24 hours before deadline
        let dayBefore = project.deadline.addingTimeInterval(-24 * 3600)
        if dayBefore > Date() {
            scheduleDeadlineNotification(
                for: project,
                at: dayBefore,
                suffix: "24h",
                message: "Your deadline for \"\(project.title)\" is tomorrow!"
            )
        }

        // Morning of deadline (9 AM)
        if let morningOf = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: project.deadline
        ), morningOf > Date() {
            scheduleDeadlineNotification(
                for: project,
                at: morningOf,
                suffix: "morning",
                message: "Today is the deadline for \"\(project.title)\"!"
            )
        }

        // Day after deadline (9 AM)
        if let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: project.deadline),
           let morningAfter = Calendar.current.date(
               bySettingHour: 9, minute: 0, second: 0, of: dayAfter
           ) {
            scheduleDeadlineNotification(
                for: project,
                at: morningAfter,
                suffix: "overdue",
                message: "Your deadline for \"\(project.title)\" has passed. Time to finish up!"
            )
        }
    }

    private func scheduleDeadlineNotification(
        for project: WritingProject,
        at date: Date,
        suffix: String,
        message: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Deadline Reminder"
        content.body = message
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: deadlineIdentifier(for: project.id, suffix: suffix),
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func cancelDeadlineNotifications(for projectId: UUID) {
        let identifiers = [
            deadlineIdentifier(for: projectId, suffix: "24h"),
            deadlineIdentifier(for: projectId, suffix: "morning"),
            deadlineIdentifier(for: projectId, suffix: "overdue")
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Bulk Operations

    func cancelAllNotifications(for projectId: UUID) {
        cancelNudgeNotification(for: projectId)
        cancelDeadlineNotifications(for: projectId)
    }

    func refreshNotifications(for projects: [WritingProject]) {
        center.removeAllPendingNotificationRequests()

        for project in projects {
            // Schedule nudge notifications based on mode
            if project.nudgeEnabled {
                scheduleNudgeNotification(for: project)
            }
            scheduleDeadlineNotifications(for: project)
        }
    }

    // MARK: - Helpers

    private func nudgeIdentifier(for projectId: UUID) -> String {
        "nudge-\(projectId.uuidString)"
    }

    private func inactivityIdentifier(for projectId: UUID) -> String {
        nudgeIdentifier(for: projectId)  // Use same identifier for backward compatibility
    }

    private func deadlineIdentifier(for projectId: UUID, suffix: String) -> String {
        "deadline-\(projectId.uuidString)-\(suffix)"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == snoozeActionIdentifier {
            let userInfo = response.notification.request.content.userInfo
            if let projectId = userInfo["projectId"] as? String,
               let projectTitle = userInfo["projectTitle"] as? String {
                scheduleSnoozeNotification(projectId: projectId, projectTitle: projectTitle)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
