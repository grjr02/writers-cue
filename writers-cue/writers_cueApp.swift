//
//  writers_cueApp.swift
//  writers-cue
//
//  Created by Gregory Ross Jr on 1/16/26.
//

import SwiftUI
import SwiftData

@main
struct writers_cueApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WritingProject.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthContainerView()
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<WritingProject>()

        guard let projects = try? context.fetch(descriptor) else { return }

        switch phase {
        case .active:
            NotificationManager.shared.refreshNotifications(for: projects)
        case .background:
            // Sync pending changes to cloud
            SyncManager.shared.appDidEnterBackground(projects: projects)

            // Schedule notifications
            for project in projects {
                if project.nudgeEnabled {
                    NotificationManager.shared.scheduleNudgeNotification(for: project)
                }
                NotificationManager.shared.scheduleDeadlineNotifications(for: project)
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
