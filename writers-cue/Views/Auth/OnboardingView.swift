import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme

    private var themeManager: ThemeManager { ThemeManager.shared }

    private var backgroundColor: Color {
        themeManager.colors(for: colorScheme).canvasBackground
    }

    private let accentBrown = Color(hex: "E4CFBA")

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (only on first page)
                HStack {
                    Spacer()
                    if currentPage == 0 {
                        Button("Skip") {
                            onComplete()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 44)

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    // Screen 1: Write Pieces
                    OnboardingPage(
                        icon: "pencil.and.outline",
                        title: "Write your pieces",
                        subtitle: "Create and manage your writing projects. Whether it's a story, article, or essay — keep everything in one place."
                    )
                    .tag(0)

                    // Screen 2: Stay on Track
                    OnboardingPage(
                        icon: "bell.badge",
                        title: "Stay on track",
                        subtitle: "Set nudges to remind you when you've been away from your writing too long. Never lose momentum on your projects."
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? accentBrown : Color.primary.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Action button
                Button {
                    if currentPage == 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage == 0 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentBrown)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String

    private let accentBrown = Color(hex: "E4CFBA")

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(accentBrown)
                .frame(height: 80)

            // Title
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(subtitle)
                .font(.system(size: 17))
                .foregroundStyle(Color.primary.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
