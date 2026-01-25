import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WritingProject.lastEditedAt, order: .reverse) private var projects: [WritingProject]

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
            ZStack {
                currentColors.canvasBackground
                    .ignoresSafeArea()

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
            .navigationDestination(for: WritingProject.self) { project in
                EditorView(project: project)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    // MARK: - Empty State

    private var footerColor: Color {
        colorScheme == .dark ? Color(hex: "444444") : Color(hex: "CCCCCC")
    }

    private var emptyStateView: some View {
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

            // CTA Button
            Button {
                showingCreateProject = true
            } label: {
                Text("Start a piece")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 24)

            Spacer()

            // Footer
            Text("Made for writers")
                .font(.system(size: 11))
                .foregroundStyle(footerColor)
                .padding(.bottom, 12)

            // Hero Illustration - full width at bottom
            Image("illustration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
        }
        .ignoresSafeArea(edges: .bottom)
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

            // Bottom illustration
            Image("illustration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
        }
        .alert("Piece Limit Reached", isPresented: $showingLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have 5 pieces in progress. Complete or remove one to start another.")
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
        modelContext.delete(project)
    }
}

// MARK: - Primary Card View

struct PrimaryCardView: View {
    let project: WritingProject
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "FFFFFF")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.primary)

            Text(project.primaryStatusText)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(2)

            Text("In progress")
                .font(.system(size: 13))
                .foregroundStyle(Color.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(16)
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
