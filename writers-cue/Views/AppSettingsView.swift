import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var themeManager: ThemeManager { ThemeManager.shared }

    private var panelBackground: Color {
        colorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FDFCFA")
    }

    private var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                panelBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        settingsSection(title: "THEME", icon: "paintbrush") {
                            HStack(spacing: 10) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    themeButton(theme)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
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
            themeManager.selectedTheme = theme
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
                    .fill(isSelected ? Color(hex: "D6E5F5").opacity(colorScheme == .dark ? 0.2 : 1.0) : inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    AppSettingsView()
}
