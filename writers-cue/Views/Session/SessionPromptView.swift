import SwiftUI

struct SessionPromptView: View {
    let onStartSession: () -> Void
    let onJustWrite: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "target")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.bottom, 20)

            // Header
            Text("Start a Writing Session?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            // Description
            Text("Set a goal and stay focused. Track your progress and optionally block distractions until you're done.")
                .font(.system(size: 16))
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            // Benefits list
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Track your writing progress")
                benefitRow(icon: "bell.slash", text: "Optional distraction blocking")
                benefitRow(icon: "party.popper", text: "Celebrate when you hit your goal")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            // Buttons
            VStack(spacing: 12) {
                // Primary: Start Session
                Button(action: onStartSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Session")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Secondary: Just Write
                Button(action: onJustWrite) {
                    Text("Just Write")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
        )
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary.opacity(0.8))
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        SessionPromptView(
            onStartSession: {},
            onJustWrite: {}
        )
        .padding()
    }
}
