import SwiftUI

struct SettingsSidePanel: View {
    @Binding var isPresented: Bool
    @Binding var documentTitle: String
    @Binding var maxInactivityHours: Int
    @Binding var nudgeMode: NudgeMode
    @Binding var nudgeHour: Int
    @Binding var nudgeMinute: Int
    @Binding var nudgeEnabled: Bool
    let onShare: () -> Void

    @State private var editingTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    @Environment(\.colorScheme) private var colorScheme

    // Computed binding for time picker
    private var nudgeTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: nudgeHour, minute: nudgeMinute)) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                nudgeHour = components.hour ?? 9
                nudgeMinute = components.minute ?? 0
            }
        )
    }

    private var panelBackground: Color {
        colorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FDFCFA")
    }

    private var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")
    }

    @ViewBuilder
    var body: some View {
        if isPresented {
            ZStack(alignment: .trailing) {
                // Dimmed background - fades in/out
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePanel()
                    }

                // Side panel
                panelContent
                    .frame(width: 320)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: 24,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(panelBackground)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: -5, y: 0)
                        .ignoresSafeArea()
                    )
                    .onAppear {
                        editingTitle = documentTitle
                    }
            }
            .transition(.opacity)
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    closePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection(title: "DOCUMENT TITLE", icon: "doc.text") {
                        TextField("Enter title", text: $editingTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(inputBackground)
                            )
                            .focused($isTitleFocused)
                            .onSubmit { saveTitle() }
                    }

                    settingsSection(title: "NUDGE", icon: "bell") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Enable/Disable toggle
                            HStack {
                                Text("Enable nudges")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.primary.opacity(0.8))
                                Spacer()
                                Toggle("", isOn: $nudgeEnabled)
                                    .labelsHidden()
                                    .tint(.blue)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(inputBackground)
                            )

                            if nudgeEnabled {
                                // Mode selection (radio buttons)
                                VStack(spacing: 0) {
                                    ForEach(NudgeMode.allCases, id: \.self) { mode in
                                        Button {
                                            nudgeMode = mode
                                        } label: {
                                            HStack {
                                                Image(systemName: nudgeMode == mode ? "circle.inset.filled" : "circle")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(nudgeMode == mode ? .blue : Color.primary.opacity(0.4))
                                                Text(mode.displayName)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.primary.opacity(0.8))
                                                Spacer()
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 14)
                                        }
                                        .buttonStyle(.plain)

                                        if mode != NudgeMode.allCases.last {
                                            Divider()
                                                .padding(.horizontal, 14)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )

                                // Conditional options based on mode
                                if nudgeMode == .afterInactivity {
                                    // Inactivity period picker
                                    HStack {
                                        Text("Inactive for")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.primary.opacity(0.8))
                                        Spacer()
                                        Picker("", selection: $maxInactivityHours) {
                                            ForEach(InactivityPeriod.allCases, id: \.rawValue) { period in
                                                Text(period.displayName).tag(period.rawValue)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(Color.primary.opacity(0.8))
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(inputBackground)
                                    )
                                }

                                // Time picker (for both modes)
                                HStack {
                                    Text(nudgeMode == .afterInactivity ? "Send nudge at" : "Remind me at")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.primary.opacity(0.8))
                                    Spacer()
                                    DatePicker("", selection: nudgeTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .tint(.blue)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(inputBackground)
                                )

                                // Helper text
                                Text(nudgeMode.helperText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            } else {
                                Text("You won't receive any nudges for this document.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: nudgeEnabled)
                        .animation(.easeInOut(duration: 0.2), value: nudgeMode)
                    }

                    settingsSection(title: "EXPORT", icon: "square.and.arrow.up") {
                        Button(action: onShare) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Share Document")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.primary.opacity(0.4))
                            }
                            .foregroundStyle(Color.primary.opacity(0.8))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(inputBackground)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .tracking(0.8)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveTitle() {
        if !editingTitle.isEmpty {
            documentTitle = editingTitle
        } else {
            editingTitle = documentTitle
        }
    }

    private func closePanel() {
        isTitleFocused = false
        saveTitle()
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
}
