import Foundation
import Supabase
import Auth

/// Manages the Supabase client connection
/// Configure with your Supabase project URL and anon key from supabase.com
@MainActor
@Observable
class SupabaseManager {
    static let shared = SupabaseManager()

    // MARK: - Configuration
    private static let supabaseURL = URL(string: "https://hvkskqqwdxohtfmlnbej.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2a3NrcXF3ZHhvaHRmbWxuYmVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNTEyODksImV4cCI6MjA4NDkyNzI4OX0.Xd5_viIcGcSnywzwbera4cchOZAgugjKWaRgJQ93jPA"

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

// MARK: - Database Models

/// Represents a writing project as stored in Supabase
/// Note: contentData is stored as Base64 string in Postgres bytea column
struct CloudProject: Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let contentData: String?  // Base64 encoded
    let deadline: Date?
    let createdAt: Date
    let lastEditedAt: Date
    let nudgeEnabled: Bool
    let nudgeMode: String
    let nudgeHour: Int
    let nudgeMinute: Int
    let maxInactivityHours: Int
    let updatedAt: Date
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case contentData = "content_data"
        case deadline
        case createdAt = "created_at"
        case lastEditedAt = "last_edited_at"
        case nudgeEnabled = "nudge_enabled"
        case nudgeMode = "nudge_mode"
        case nudgeHour = "nudge_hour"
        case nudgeMinute = "nudge_minute"
        case maxInactivityHours = "max_inactivity_hours"
        case updatedAt = "updated_at"
        case isArchived = "is_archived"
    }

    /// Get contentData as Data (decoding from Base64)
    var contentDataAsData: Data? {
        guard let base64String = contentData else { return nil }
        return Data(base64Encoded: base64String)
    }
}

/// Struct for inserting/updating projects
/// Note: contentData should be Base64 encoded before assignment
struct CloudProjectInsert: Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let contentData: String?  // Base64 encoded
    let deadline: Date?
    let createdAt: Date
    let lastEditedAt: Date
    let nudgeEnabled: Bool
    let nudgeMode: String
    let nudgeHour: Int
    let nudgeMinute: Int
    let maxInactivityHours: Int
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case contentData = "content_data"
        case deadline
        case createdAt = "created_at"
        case lastEditedAt = "last_edited_at"
        case nudgeEnabled = "nudge_enabled"
        case nudgeMode = "nudge_mode"
        case nudgeHour = "nudge_hour"
        case nudgeMinute = "nudge_minute"
        case maxInactivityHours = "max_inactivity_hours"
        case isArchived = "is_archived"
    }
}

// MARK: - Feedback

enum FeedbackCategory: String, CaseIterable {
    case general = "general"
    case bug = "bug"

    var displayName: String {
        switch self {
        case .general: return "General Feedback"
        case .bug: return "Something's Not Working"
        }
    }
}

struct FeedbackInsert: Codable {
    let userId: UUID
    let category: String
    let comment: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case category
        case comment
    }
}

extension SupabaseManager {
    func submitFeedback(category: FeedbackCategory, comment: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw FeedbackError.notAuthenticated
        }

        let feedback = FeedbackInsert(
            userId: userId,
            category: category.rawValue,
            comment: comment
        )

        try await client
            .from("feedback")
            .insert(feedback)
            .execute()
    }
}

enum FeedbackError: LocalizedError {
    case notAuthenticated
    case submissionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to submit feedback"
        case .submissionFailed:
            return "Failed to submit feedback"
        }
    }
}
