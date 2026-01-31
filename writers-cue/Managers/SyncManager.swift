import Foundation
import Supabase
import SwiftData
import Auth

/// Handles cloud synchronization for writing projects
@MainActor
@Observable
class SyncManager {
    static let shared = SyncManager()

    // MARK: - State

    enum SyncStatus {
        case idle
        case syncing
        case synced
        case offline
        case error(String)
    }

    private(set) var status: SyncStatus = .idle
    private(set) var lastSyncedAt: Date?

    /// Debounce timer for auto-sync after edits
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 30  // 30 seconds
    private weak var pendingProject: WritingProject?

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Sync Triggers

    /// Called when content is edited - starts debounce timer
    func contentDidChange(project: WritingProject) {
        guard AuthManager.shared.isSignedIn else { return }

        // Mark as needing sync
        project.needsSync = true

        // Reset debounce timer
        debounceTimer?.invalidate()
        pendingProject = project
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let project = self.pendingProject else { return }
                await self.uploadProject(project)
            }
        }
    }

    /// Called when leaving the editor - sync immediately
    func editorWillDisappear(project: WritingProject) {
        guard AuthManager.shared.isSignedIn, project.needsSync else { return }

        debounceTimer?.invalidate()
        Task {
            await uploadProject(project)
        }
    }

    /// Called when app goes to background - sync all pending
    func appDidEnterBackground(projects: [WritingProject]) {
        guard AuthManager.shared.isSignedIn else { return }

        debounceTimer?.invalidate()

        Task {
            for project in projects where project.needsSync {
                await uploadProject(project)
            }
        }
    }

    /// Called on app launch - pull changes from cloud
    func appDidBecomeActive(modelContext: ModelContext) async {
        guard AuthManager.shared.isSignedIn else { return }
        await pullFromCloud(modelContext: modelContext)
    }

    // MARK: - Upload

    /// Upload a single project to the cloud
    func uploadProject(_ project: WritingProject) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        status = .syncing

        do {
            // Check for conflicts first
            if let cloudProject = try await fetchCloudProject(id: project.id) {
                let hasConflict = cloudProject.lastEditedAt > (project.lastSyncedAt ?? .distantPast)
                    && project.needsSync

                if hasConflict {
                    // Conflict detected - need user decision
                    status = .error("Conflict detected")
                    // The UI will handle showing the conflict resolution dialog
                    return
                }
            }

            // Encrypt title and content before upload
            let encryptedTitle = try EncryptionManager.shared.encrypt(
                project.title.data(using: .utf8) ?? Data(),
                userId: userId.uuidString
            )
            let base64Title = encryptedTitle.base64EncodedString()

            let encryptedContent = try EncryptionManager.shared.encrypt(
                project.contentData,
                userId: userId.uuidString
            )
            let base64Content = encryptedContent.base64EncodedString()

            let insert = CloudProjectInsert(
                id: project.id,
                userId: userId,
                title: base64Title,
                contentData: base64Content,
                deadline: project.deadline,
                createdAt: project.createdAt,
                lastEditedAt: project.lastEditedAt,
                nudgeEnabled: project.nudgeEnabled,
                nudgeMode: project.nudgeMode.rawValue == 0 ? "afterInactivity" : "daily",
                nudgeHour: project.nudgeHour,
                nudgeMinute: project.nudgeMinute,
                maxInactivityHours: project.maxInactivityHours,
                isArchived: project.isArchived
            )

            try await supabase
                .from("writing_projects")
                .upsert(insert)
                .execute()

            project.needsSync = false
            project.lastSyncedAt = Date()
            lastSyncedAt = Date()
            status = .synced

        } catch {
            print("Upload failed: \(error)")
            status = .error(error.localizedDescription)
        }
    }

    /// Upload all local projects (used when user first signs in)
    func uploadAllProjects(_ projects: [WritingProject]) async {
        for project in projects {
            project.needsSync = true
            await uploadProject(project)
        }
    }

    // MARK: - Download

    /// Fetch all projects from cloud and merge with local
    func pullFromCloud(modelContext: ModelContext) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        status = .syncing

        do {
            let cloudProjects: [CloudProject] = try await supabase
                .from("writing_projects")
                .select()
                .execute()
                .value

            for cloudProject in cloudProjects {
                // Check if project exists locally
                let descriptor = FetchDescriptor<WritingProject>(
                    predicate: #Predicate { $0.id == cloudProject.id }
                )
                let localProjects = try modelContext.fetch(descriptor)

                if let localProject = localProjects.first {
                    // Project exists - check for conflicts
                    let cloudIsNewer = cloudProject.lastEditedAt > (localProject.lastSyncedAt ?? .distantPast)
                    let localHasChanges = localProject.needsSync

                    if cloudIsNewer && localHasChanges {
                        // Conflict - will be resolved by UI
                        continue
                    } else if cloudIsNewer {
                        // Cloud is newer, no local changes - update local
                        updateLocalProject(localProject, from: cloudProject, userId: userId.uuidString)
                    }
                    // If local is newer or same, will be uploaded on next sync
                } else {
                    // Project doesn't exist locally - create it
                    let newProject = createLocalProject(from: cloudProject, userId: userId.uuidString)
                    modelContext.insert(newProject)
                }
            }

            try modelContext.save()
            lastSyncedAt = Date()
            status = .synced

        } catch {
            print("Pull from cloud failed: \(error)")
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Conflict Resolution

    /// Keep the local version, overwrite cloud
    func resolveConflictKeepLocal(_ project: WritingProject) async {
        project.needsSync = true
        await uploadProject(project)
    }

    /// Keep the cloud version, discard local changes
    func resolveConflictKeepCloud(_ project: WritingProject, modelContext: ModelContext) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            if let cloudProject = try await fetchCloudProject(id: project.id) {
                updateLocalProject(project, from: cloudProject, userId: userId.uuidString)
                project.needsSync = false
                project.lastSyncedAt = Date()
                try modelContext.save()
                status = .synced
            }
        } catch {
            print("Conflict resolution failed: \(error)")
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Delete

    /// Delete a project from cloud
    func deleteFromCloud(projectId: UUID) async {
        guard AuthManager.shared.isSignedIn else { return }

        do {
            try await supabase
                .from("writing_projects")
                .delete()
                .eq("id", value: projectId.uuidString)
                .execute()
        } catch {
            print("Delete from cloud failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func fetchCloudProject(id: UUID) async throws -> CloudProject? {
        let projects: [CloudProject] = try await supabase
            .from("writing_projects")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value

        return projects.first
    }

    private func updateLocalProject(_ local: WritingProject, from cloud: CloudProject, userId: String) {
        // Decode Base64 and decrypt title
        if let encryptedTitleData = Data(base64Encoded: cloud.title) {
            do {
                let decryptedTitleData = try EncryptionManager.shared.decrypt(encryptedTitleData, userId: userId)
                local.title = String(data: decryptedTitleData, encoding: .utf8) ?? cloud.title
            } catch {
                print("Failed to decrypt title: \(error)")
                local.title = cloud.title // Fallback to encrypted title if decryption fails
            }
        } else {
            local.title = cloud.title // Fallback for unencrypted titles
        }

        // Decode Base64 and decrypt content
        if let base64Content = cloud.contentData,
           let encryptedData = Data(base64Encoded: base64Content) {
            do {
                local.contentData = try EncryptionManager.shared.decrypt(encryptedData, userId: userId)
            } catch {
                print("Failed to decrypt content: \(error)")
            }
        }

        local.deadline = cloud.deadline ?? local.deadline
        local.lastEditedAt = cloud.lastEditedAt
        local.nudgeEnabled = cloud.nudgeEnabled
        local.nudgeMode = cloud.nudgeMode == "daily" ? .daily : .afterInactivity
        local.nudgeHour = cloud.nudgeHour
        local.nudgeMinute = cloud.nudgeMinute
        local.maxInactivityHours = cloud.maxInactivityHours
        local.isArchived = cloud.isArchived
        local.lastSyncedAt = Date()
        local.needsSync = false
    }

    private func createLocalProject(from cloud: CloudProject, userId: String) -> WritingProject {
        // Decrypt title
        var decryptedTitle = cloud.title
        if let encryptedTitleData = Data(base64Encoded: cloud.title) {
            do {
                let decryptedTitleData = try EncryptionManager.shared.decrypt(encryptedTitleData, userId: userId)
                decryptedTitle = String(data: decryptedTitleData, encoding: .utf8) ?? cloud.title
            } catch {
                print("Failed to decrypt title: \(error)")
            }
        }

        let project = WritingProject(
            title: decryptedTitle,
            deadline: cloud.deadline ?? Date().addingTimeInterval(7 * 24 * 3600),
            maxInactivityHours: cloud.maxInactivityHours
        )

        // Use the same ID as cloud
        project.id = cloud.id
        project.createdAt = cloud.createdAt

        // Decode Base64 and decrypt content
        if let base64Content = cloud.contentData,
           let encryptedData = Data(base64Encoded: base64Content) {
            do {
                project.contentData = try EncryptionManager.shared.decrypt(encryptedData, userId: userId)
            } catch {
                print("Failed to decrypt content: \(error)")
            }
        }

        project.lastEditedAt = cloud.lastEditedAt
        project.nudgeEnabled = cloud.nudgeEnabled
        project.nudgeMode = cloud.nudgeMode == "daily" ? .daily : .afterInactivity
        project.nudgeHour = cloud.nudgeHour
        project.nudgeMinute = cloud.nudgeMinute
        project.isArchived = cloud.isArchived
        project.lastSyncedAt = Date()
        project.needsSync = false

        return project
    }
}
