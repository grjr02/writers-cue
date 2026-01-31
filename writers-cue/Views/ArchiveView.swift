import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WritingProject.lastEditedAt, order: .reverse) private var allProjects: [WritingProject]

    private var themeManager: ThemeManager { ThemeManager.shared }

    private let maxActiveProjects = 5

    private var archivedProjects: [WritingProject] {
        allProjects.filter { $0.isArchived }
    }

    private var activeProjectCount: Int {
        allProjects.filter { !$0.isArchived }.count
    }

    private var canUnarchive: Bool {
        activeProjectCount < maxActiveProjects
    }

    // Get ACTUAL system color scheme (not the sheet's overridden context)
    private var systemColorScheme: ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    private var effectiveColorScheme: ColorScheme {
        themeManager.colorScheme ?? systemColorScheme
    }

    private var panelBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FDFCFA")
    }

    private var inputBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")
    }

    @State private var showUnarchiveLimitAlert = false
    @State private var showUnarchiveConfirmation = false
    @State private var projectToUnarchive: WritingProject?

    var body: some View {
        NavigationStack {
            ZStack {
                panelBackground
                    .ignoresSafeArea()

                if archivedProjects.isEmpty {
                    emptyStateView
                } else {
                    archiveListView
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Cannot Unarchive", isPresented: $showUnarchiveLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You have 5 active pieces. Archive or delete one before unarchiving this piece.")
            }
            .alert("Unarchive Story", isPresented: $showUnarchiveConfirmation) {
                Button("Cancel", role: .cancel) {
                    projectToUnarchive = nil
                }
                Button("Unarchive") {
                    if let project = projectToUnarchive {
                        unarchiveProject(project)
                    }
                    projectToUnarchive = nil
                }
            } message: {
                Text("Do you want to unarchive this story?")
            }
        }
        .preferredColorScheme(effectiveColorScheme)
        .id(effectiveColorScheme)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(Color.primary.opacity(0.3))

            Text("No Archived Pieces")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.6))

            Text("Archived pieces will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(Color.primary.opacity(0.4))
        }
    }

    // MARK: - Archive List

    private var archiveListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(archivedProjects) { project in
                    archivedProjectRow(project)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    private func archivedProjectRow(_ project: WritingProject) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text("Archived \(project.lastEditedDescription)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            Spacer()

            // Unarchive button
            Button {
                projectToUnarchive = project
                if canUnarchive {
                    showUnarchiveConfirmation = true
                } else {
                    showUnarchiveLimitAlert = true
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(canUnarchive ? Color(hex: "E4CFBA") : Color.primary.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(canUnarchive ? Color(hex: "E4CFBA").opacity(0.15) : Color.primary.opacity(0.05))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(inputBackground)
        )
        .contextMenu {
            Button {
                projectToUnarchive = project
                if canUnarchive {
                    showUnarchiveConfirmation = true
                } else {
                    showUnarchiveLimitAlert = true
                }
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }

            Button(role: .destructive) {
                deleteProject(project)
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func unarchiveProject(_ project: WritingProject) {
        guard canUnarchive else {
            showUnarchiveLimitAlert = true
            return
        }

        project.isArchived = false
        project.needsSync = true

        // Reschedule notifications for unarchived projects
        NotificationManager.shared.scheduleDeadlineNotifications(for: project)

        Task {
            await SyncManager.shared.uploadProject(project)
        }
    }

    private func deleteProject(_ project: WritingProject) {
        NotificationManager.shared.cancelAllNotifications(for: project.id)

        let projectId = project.id
        Task {
            await SyncManager.shared.deleteFromCloud(projectId: projectId)
        }

        modelContext.delete(project)
    }
}

#Preview {
    ArchiveView()
        .modelContainer(for: WritingProject.self, inMemory: true)
}
