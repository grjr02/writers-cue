import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var documentTitle: String
    @Binding var maxInactivityHours: Int
    @Binding var nudgeMode: NudgeMode
    @Binding var nudgeHour: Int
    @Binding var nudgeMinute: Int
    @Binding var nudgeEnabled: Bool
    let onShare: () -> Void

    private var themeManager: ThemeManager { ThemeManager.shared }
    @State private var editingTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    // Get ACTUAL system color scheme (not the sheet's overridden context)
    private var systemColorScheme: ColorScheme {
        // UIScreen.main.traitCollection gives the real system setting,
        // not the view's overridden preferredColorScheme
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    // Use explicit color scheme - for auto, detect actual system setting
    private var effectiveColorScheme: ColorScheme {
        themeManager.colorScheme ?? systemColorScheme
    }

    private var currentColors: ThemeColors {
        themeManager.colors(for: effectiveColorScheme)
    }

    private var inputBackground: Color {
        effectiveColorScheme == .dark ? Color(hex: "333333") : Color(hex: "F0F0F0")
    }

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

    var body: some View {
        NavigationStack {
            ZStack {
                currentColors.canvasBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Document Title Section
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
                                .onSubmit {
                                    saveTitle()
                                }
                                .onChange(of: isTitleFocused) { _, focused in
                                    if !focused {
                                        saveTitle()
                                    }
                                }
                        }

                        // Theme Section
                        settingsSection(title: "THEME", icon: "paintbrush") {
                            HStack(spacing: 10) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    themeButton(theme)
                                }
                            }
                        }

                        // Nudge Section
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
                                        .tint(Color(hex: "E4CFBA"))
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
                                                        .foregroundStyle(nudgeMode == mode ? Color(hex: "E4CFBA") : Color.primary.opacity(0.4))
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
                                            .tint(Color(hex: "E4CFBA"))
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
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("You won't receive any nudges for this document.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.primary.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: nudgeEnabled)
                            .animation(.easeInOut(duration: 0.2), value: nudgeMode)
                        }

                        // Export Section
                        settingsSection(title: "EXPORT", icon: "square.and.arrow.up") {
                            Button {
                                onShare()
                            } label: {
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
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveTitle()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            editingTitle = documentTitle
        }
        .preferredColorScheme(effectiveColorScheme)
        .id(effectiveColorScheme) // Force full view recreation when theme changes
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

    private func themeButton(_ theme: AppTheme) -> some View {
        let isSelected = themeManager.selectedTheme == theme

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                themeManager.selectedTheme = theme
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.45))

                Text(theme.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "D6E5F5").opacity(effectiveColorScheme == .dark ? 0.2 : 1.0) : inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private func saveTitle() {
        if !editingTitle.isEmpty {
            documentTitle = editingTitle
        } else {
            editingTitle = documentTitle
        }
    }
}

#Preview {
    SettingsSheetView(
        documentTitle: .constant("Test Document"),
        maxInactivityHours: .constant(48),
        nudgeMode: .constant(.afterInactivity),
        nudgeHour: .constant(9),
        nudgeMinute: .constant(0),
        nudgeEnabled: .constant(true),
        onShare: {}
    )
}
