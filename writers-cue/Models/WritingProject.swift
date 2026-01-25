import Foundation
import SwiftData
import UIKit

// MARK: - Nudge Mode

enum NudgeMode: Int, Codable, CaseIterable {
    case afterInactivity = 0
    case daily = 1

    var displayName: String {
        switch self {
        case .afterInactivity: return "After inactivity"
        case .daily: return "Daily reminder"
        }
    }

    var helperText: String {
        switch self {
        case .afterInactivity:
            return "You'll receive a nudge at your preferred time once the inactivity period has passed."
        case .daily:
            return "You'll receive a daily nudge at this time to keep writing."
        }
    }
}

// MARK: - Inactivity Period Options

enum InactivityPeriod: Int, CaseIterable {
    case oneDay = 24
    case twoDays = 48
    case threeDays = 72
    case fiveDays = 120
    case oneWeek = 168

    var displayName: String {
        switch self {
        case .oneDay: return "1 day"
        case .twoDays: return "2 days"
        case .threeDays: return "3 days"
        case .fiveDays: return "5 days"
        case .oneWeek: return "1 week"
        }
    }
}

@Model
final class WritingProject {
    var id: UUID
    var title: String
    var contentData: Data
    var deadline: Date
    var maxInactivityHours: Int
    var createdAt: Date
    var lastEditedAt: Date
    var lastProgressAt: Date?

    // Nudge settings (optional for migration compatibility with existing data)
    var nudgeModeRaw: Int?  // NudgeMode raw value (0 = afterInactivity, 1 = daily)
    var nudgeTimeHour: Int?  // Hour component (0-23) for preferred nudge time
    var nudgeTimeMinute: Int?  // Minute component (0-59) for preferred nudge time
    var nudgeEnabledRaw: Bool?  // Whether nudges are enabled at all

    // Computed properties with defaults for nil values
    var nudgeMode: NudgeMode {
        get { NudgeMode(rawValue: nudgeModeRaw ?? 0) ?? .afterInactivity }
        set { nudgeModeRaw = newValue.rawValue }
    }

    var nudgeHour: Int {
        get { nudgeTimeHour ?? 9 }
        set { nudgeTimeHour = newValue }
    }

    var nudgeMinute: Int {
        get { nudgeTimeMinute ?? 0 }
        set { nudgeTimeMinute = newValue }
    }

    var nudgeEnabled: Bool {
        get { nudgeEnabledRaw ?? (maxInactivityHours > 0) }
        set { nudgeEnabledRaw = newValue }
    }

    /// Returns the next occurrence of the preferred nudge time
    var preferredNudgeTime: DateComponents {
        DateComponents(hour: nudgeHour, minute: nudgeMinute)
    }

    init(
        title: String,
        deadline: Date,
        maxInactivityHours: Int
    ) {
        self.id = UUID()
        self.title = title
        self.contentData = Data()
        self.deadline = deadline
        self.maxInactivityHours = maxInactivityHours
        self.createdAt = Date()
        self.lastEditedAt = Date()
        self.lastProgressAt = nil

        // Default nudge settings
        self.nudgeModeRaw = NudgeMode.afterInactivity.rawValue
        self.nudgeTimeHour = 9  // Default: 9:00 AM
        self.nudgeTimeMinute = 0
        self.nudgeEnabledRaw = maxInactivityHours > 0
    }

    var attributedContent: NSAttributedString {
        get {
            guard !contentData.isEmpty else {
                return NSAttributedString(string: "")
            }
            do {
                return try NSAttributedString(
                    data: contentData,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
            } catch {
                return NSAttributedString(string: "")
            }
        }
        set {
            do {
                contentData = try newValue.data(
                    from: NSRange(location: 0, length: newValue.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
            } catch {
                contentData = Data()
            }
        }
    }

    var plainTextContent: String {
        attributedContent.string
    }

    var wordCount: Int {
        plainTextContent.split { $0.isWhitespace || $0.isNewline }.count
    }

    var daysUntilDeadline: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
    }

    var lastEditedDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastEditedAt, relativeTo: Date())
    }

    /// Status text for primary card: "Last edited just now", "Last edited today", etc.
    var primaryStatusText: String {
        let calendar = Calendar.current
        let now = Date()

        // Within last hour
        if let hourAgo = calendar.date(byAdding: .hour, value: -1, to: now),
           lastEditedAt > hourAgo {
            return "Last edited just now"
        }

        // Today
        if calendar.isDateInToday(lastEditedAt) {
            return "Last edited today"
        }

        // Yesterday
        if calendar.isDateInYesterday(lastEditedAt) {
            return "Last edited yesterday"
        }

        // Within last week
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           lastEditedAt > weekAgo {
            let days = calendar.dateComponents([.day], from: lastEditedAt, to: now).day ?? 0
            return "Last edited \(days) days ago"
        }

        // More than a week
        return "Last edited last week"
    }
}
