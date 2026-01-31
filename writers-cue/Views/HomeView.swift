import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WritingProject.lastEditedAt, order: .reverse) private var allProjects: [WritingProject]

    private var projects: [WritingProject] {
        allProjects.filter { !$0.isArchived }
    }

    @State private var showingCreateProject = false
    @State private var navigationPath = NavigationPath()
    private var themeManager: ThemeManager { ThemeManager.shared }

    private let maxProjects = 5

    private var canCreateProject: Bool {
        projects.count < maxProjects
    }

    private var currentColors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }

    private var taglineColor: Color {
        colorScheme == .dark ? Color(hex: "9A9A9A") : Color(hex: "6B6B6B")
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                currentColors.canvasBackground
                    .ignoresSafeArea()

                // Fixed position illustration at bottom
                Image("illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .ignoresSafeArea(edges: .bottom)

                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectsView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView { project in
                    modelContext.insert(project)
                    NotificationManager.shared.scheduleDeadlineNotifications(for: project)
                    navigationPath.append(project)
                }
            }
            .sheet(isPresented: $showingAppSettings) {
                AppSettingsView()
            }
            .navigationDestination(for: WritingProject.self) { project in
                EditorView(project: project)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ZStack {
            // Settings button at top right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingAppSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }

            // Content with button vertically centered
            VStack(spacing: 0) {
                Spacer()

                // Title
                Text("Writer's Cue")
                    .font(.system(size: 30, weight: .bold))

                // Tagline
                Text("This is your signal.\nThis is where writing continues.")
                    .font(.system(size: 17))
                    .foregroundStyle(taglineColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                // CTA Button - this is the vertical center
                Button {
                    showingCreateProject = true
                } label: {
                    Text("Start a piece")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color(hex: "E4CFBA"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 24)

                Spacer()

                // Invisible spacer to offset content above button, centering the button
                Color.clear.frame(height: 120)
            }
        }
    }

    @State private var showingAppSettings = false
    @State private var showingLimitAlert = false

    // Primary project (most recently edited)
    private var primaryProject: WritingProject? {
        projects.first
    }

    // Secondary projects (next 4 most recent)
    private var secondaryProjects: [WritingProject] {
        Array(projects.dropFirst().prefix(4))
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color(hex: "888888") : Color(hex: "8A8A8A")
    }

    // MARK: - Projects View

    private var projectsView: some View {
        VStack(spacing: 0) {
            // Header with title and settings button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Writer's Cue")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Welcome back. Let's continue writing.")
                        .font(.system(size: 15))
                        .foregroundStyle(subtitleColor)
                }

                Spacer()

                Button {
                    showingAppSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)

            VStack(spacing: 16) {
                // Primary Card (Last Edited)
                if let primary = primaryProject {
                    NavigationLink(value: primary) {
                        PrimaryCardView(project: primary)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            archiveProject(primary)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        Button(role: .destructive) {
                            deleteProject(primary)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Secondary Cards (2x2 Grid)
                if !secondaryProjects.isEmpty {
                    secondaryCardsGrid
                }

                // Start a piece link (demoted)
                startPieceLink
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .alert("Piece Limit Reached", isPresented: $showingLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have 5 active pieces. Archive or remove one to start another. You can do this by holding down on a writing.")
        }
    }

    // MARK: - Secondary Cards Grid

    private var secondaryCardsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(secondaryProjects) { project in
                NavigationLink(value: project) {
                    SecondaryCardView(project: project)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        archiveProject(project)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    Button(role: .destructive) {
                        deleteProject(project)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var startPieceLinkColor: Color {
        colorScheme == .dark ? Color(hex: "999999") : Color(hex: "666666")
    }

    // MARK: - Start a Piece Link

    private var startPieceLink: some View {
        Button {
            if canCreateProject {
                showingCreateProject = true
            } else {
                showingLimitAlert = true
            }
        } label: {
            Text("Start a piece")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(startPieceLinkColor)
                .frame(minHeight: 44)
        }
    }

    private func deleteProject(_ project: WritingProject) {
        NotificationManager.shared.cancelAllNotifications(for: project.id)

        // Delete from cloud if signed in
        let projectId = project.id
        Task {
            await SyncManager.shared.deleteFromCloud(projectId: projectId)
        }

        modelContext.delete(project)
    }

    private func archiveProject(_ project: WritingProject) {
        // Cancel notifications for archived projects
        NotificationManager.shared.cancelAllNotifications(for: project.id)

        project.isArchived = true
        project.needsSync = true

        Task {
            await SyncManager.shared.uploadProject(project)
        }
    }
}

// MARK: - Activity Status

enum ActivityStatus {
    case active      // Green - on track, recently edited
    case approaching // Yellow - approaching nudge time, needs attention soon
    case overdue     // Orange - past nudge/inactivity period
    case critical    // Deep Red - deadline imminent (within 5 min)

    var color: Color {
        switch self {
        case .active: return Color(hex: "73a95b")      // Green
        case .approaching: return Color(hex: "c38839") // Yellow/Amber
        case .overdue: return Color(hex: "b3573a")     // Orange
        case .critical: return Color(hex: "D32F2F")    // Deep Red
        }
    }

    /// Determines activity status based on project settings
    /// Priority: 1. Deadline critical, 2. Nudge-based status, 3. Simple time-based
    static func from(project: WritingProject) -> ActivityStatus {
        let calendar = Calendar.current
        let now = Date()

        // PRIORITY 1: Check deadline urgency (within 5 minutes before or after)
        let minutesToDeadline = calendar.dateComponents([.minute], from: now, to: project.deadline).minute ?? 0
        if abs(minutesToDeadline) <= 5 {
            return .critical
        }

        // PRIORITY 2: If nudge is enabled, use nudge-based logic
        if project.nudgeEnabled {
            return statusFromNudgeSettings(project: project, calendar: calendar, now: now)
        }

        // PRIORITY 3: Fallback to simple time-based logic (no nudge configured)
        return simpleTimeBasedStatus(lastEditedAt: project.lastEditedAt, calendar: calendar, now: now)
    }

    /// Status based on nudge settings (inactivity or daily mode)
    private static func statusFromNudgeSettings(project: WritingProject, calendar: Calendar, now: Date) -> ActivityStatus {
        let lastEditedAt = project.lastEditedAt

        switch project.nudgeMode {
        case .afterInactivity:
            return inactivityModeStatus(project: project, calendar: calendar, now: now)
        case .daily:
            return dailyModeStatus(project: project, calendar: calendar, now: now)
        }
    }

    /// Status for inactivity mode: nudge fires after X hours of inactivity at preferred time
    private static func inactivityModeStatus(project: WritingProject, calendar: Calendar, now: Date) -> ActivityStatus {
        let lastEditedAt = project.lastEditedAt
        let inactivityThreshold = project.maxInactivityHours

        // Calculate when inactivity period ends
        guard let inactivityEndTime = calendar.date(byAdding: .hour, value: inactivityThreshold, to: lastEditedAt) else {
            return .active
        }

        // If we haven't reached the inactivity threshold yet, we're active
        if now < inactivityEndTime {
            // Check if we're within 1 hour of the inactivity threshold
            let hoursUntilThreshold = calendar.dateComponents([.hour], from: now, to: inactivityEndTime).hour ?? 0
            if hoursUntilThreshold <= 1 && hoursUntilThreshold >= 0 {
                return .approaching
            }
            return .active
        }

        // Inactivity threshold has passed - find when the nudge would fire
        // The nudge fires at the preferred time (nudgeHour:nudgeMinute) after the threshold
        let nudgeTime = nextNudgeTime(after: inactivityEndTime, hour: project.nudgeHour, minute: project.nudgeMinute, calendar: calendar)

        // Calculate time difference to nudge time
        let minutesToNudge = calendar.dateComponents([.minute], from: now, to: nudgeTime).minute ?? 0

        // Within 1 hour before or after nudge time = approaching
        if abs(minutesToNudge) <= 60 {
            return .approaching
        }

        // Past nudge time by more than 1 hour = overdue
        if now > nudgeTime {
            return .overdue
        }

        // Before nudge time but inactivity threshold passed
        return .approaching
    }

    /// Status for daily mode: nudge fires at preferred time each day
    private static func dailyModeStatus(project: WritingProject, calendar: Calendar, now: Date) -> ActivityStatus {
        let lastEditedAt = project.lastEditedAt

        // Get today's nudge time
        var todayNudgeComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayNudgeComponents.hour = project.nudgeHour
        todayNudgeComponents.minute = project.nudgeMinute

        guard let todayNudgeTime = calendar.date(from: todayNudgeComponents) else {
            return .active
        }

        // If edited today, we're active
        if calendar.isDateInToday(lastEditedAt) {
            // But check if we're approaching the nudge time
            let minutesToNudge = calendar.dateComponents([.minute], from: now, to: todayNudgeTime).minute ?? 0
            if minutesToNudge > 0 && minutesToNudge <= 60 {
                return .approaching
            }
            return .active
        }

        // Not edited today - check nudge time
        let minutesToNudge = calendar.dateComponents([.minute], from: now, to: todayNudgeTime).minute ?? 0

        // Within 1 hour of nudge time (before or after)
        if abs(minutesToNudge) <= 60 {
            return .approaching
        }

        // Past today's nudge time and not edited today
        if now > todayNudgeTime {
            return .overdue
        }

        // Before nudge time, not edited today yet
        return .approaching
    }

    /// Simple time-based status when nudge is not configured
    private static func simpleTimeBasedStatus(lastEditedAt: Date, calendar: Calendar, now: Date) -> ActivityStatus {
        if calendar.isDateInToday(lastEditedAt) {
            return .active
        }

        let daysSinceEdit = calendar.dateComponents([.day], from: lastEditedAt, to: now).day ?? 0

        if daysSinceEdit >= 3 {
            return .overdue
        } else {
            return .approaching
        }
    }

    /// Helper: Get the next occurrence of a specific time after a given date
    private static func nextNudgeTime(after date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        guard let nudgeTimeOnSameDay = calendar.date(from: components) else {
            return date
        }

        // If the nudge time on the same day is after our date, use it
        if nudgeTimeOnSameDay > date {
            return nudgeTimeOnSameDay
        }

        // Otherwise, use the next day's nudge time
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: nudgeTimeOnSameDay) else {
            return date
        }

        return nextDay
    }
}

// MARK: - Primary Card View

struct PrimaryCardView: View {
    let project: WritingProject
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "FFFFFF")
    }

    private var activityStatus: ActivityStatus {
        ActivityStatus.from(project: project)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(activityStatus.color)
                .frame(width: 4)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text(project.primaryStatusText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18)
            .padding(.trailing, 22)
            .padding(.vertical, 22)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Secondary Card View

struct SecondaryCardView: View {
    let project: WritingProject
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "FFFFFF")
    }

    private var activityStatus: ActivityStatus {
        ActivityStatus.from(project: project)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(activityStatus.color)
                .frame(width: 4)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Text(project.secondaryStatusText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    HomeView()
        .modelContainer(for: WritingProject.self, inMemory: true)
}
