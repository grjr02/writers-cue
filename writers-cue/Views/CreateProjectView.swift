import SwiftUI

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    // Nudge settings
    @State private var nudgeEnabled = true
    @State private var nudgeMode: NudgeMode = .afterInactivity
    @State private var selectedInactivityPeriod: InactivityPeriod = .twoDays
    @State private var nudgeTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    private var themeManager: ThemeManager { ThemeManager.shared }

    let onCreate: (WritingProject) -> Void

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && deadline > Date()
    }

    private var currentColors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                currentColors.canvasBackground
                    .ignoresSafeArea()

                Form {
                    Section("Project Details") {
                        TextField("Article Title", text: $title)

                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            in: minimumDate...,
                            displayedComponents: .date
                        )
                    }
                    .listRowBackground(
                        colorScheme == .dark
                            ? Color(hex: "252525")
                            : Color(hex: "FDFCFA")
                    )

                    Section {
                        Toggle("Enable nudges", isOn: $nudgeEnabled)
                            .tint(Color(hex: "E4CFBA"))
                    } footer: {
                        Text(nudgeEnabled
                             ? "You'll receive gentle reminders to keep writing."
                             : "You won't receive any nudges for this document.")
                    }
                    .listRowBackground(
                        colorScheme == .dark
                            ? Color(hex: "252525")
                            : Color(hex: "FDFCFA")
                    )

                    if nudgeEnabled {
                        Section {
                            Picker("Mode", selection: $nudgeMode) {
                                ForEach(NudgeMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if nudgeMode == .afterInactivity {
                                Picker("Inactive for", selection: $selectedInactivityPeriod) {
                                    ForEach(InactivityPeriod.allCases, id: \.rawValue) { period in
                                        Text(period.displayName).tag(period)
                                    }
                                }
                            }

                            DatePicker(
                                nudgeMode == .afterInactivity ? "Send nudge at" : "Remind me at",
                                selection: $nudgeTime,
                                displayedComponents: .hourAndMinute
                            )
                        } header: {
                            Text("Nudge Type")
                        } footer: {
                            Text(nudgeMode.helperText)
                        }
                        .listRowBackground(
                            colorScheme == .dark
                                ? Color(hex: "252525")
                                : Color(hex: "FDFCFA")
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .animation(.easeInOut(duration: 0.2), value: nudgeEnabled)
                .animation(.easeInOut(duration: 0.2), value: nudgeMode)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Writing") {
                        let project = WritingProject(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            deadline: deadline,
                            maxInactivityHours: selectedInactivityPeriod.rawValue
                        )

                        // Apply nudge settings
                        project.nudgeEnabled = nudgeEnabled
                        project.nudgeMode = nudgeMode
                        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: nudgeTime)
                        project.nudgeHour = timeComponents.hour ?? 9
                        project.nudgeMinute = timeComponents.minute ?? 0

                        onCreate(project)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
}

#Preview {
    CreateProjectView { _ in }
}
