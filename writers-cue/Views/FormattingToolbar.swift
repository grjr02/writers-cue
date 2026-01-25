import SwiftUI

struct FormattingToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onTitle: () -> Void      // H1
    let onHeading: () -> Void    // H2
    let onSubheading: () -> Void // H3
    let onBody: () -> Void
    let onToggleKeyboard: () -> Void
    let isKeyboardVisible: Bool
    var isBoldActive: Bool = false
    var isItalicActive: Bool = false
    var isUnderlineActive: Bool = false
    var currentStyle: TextStyle = .body

    @State private var isExpanded = false

    private let buttonSize: CGFloat = 40
    private let iconSize: CGFloat = 17

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content area when expanded
            if isExpanded {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        // Paragraph styles section
                        VStack(spacing: 2) {
                            paragraphButton(label: "H1", isActive: currentStyle == .title, action: {
                                onTitle()
                            })
                            paragraphButton(label: "H2", isActive: currentStyle == .heading, action: {
                                onHeading()
                            })
                            paragraphButton(label: "H3", isActive: currentStyle == .subheading, action: {
                                onSubheading()
                            })
                            paragraphButton(label: "¶", isActive: currentStyle == .body, action: {
                                onBody()
                            })
                        }

                        // Divider
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 24, height: 1)
                            .padding(.vertical, 8)

                        // Inline formatting section
                        VStack(spacing: 2) {
                            formatButton(icon: "bold", isActive: isBoldActive, action: onBold)
                            formatButton(icon: "italic", isActive: isItalicActive, action: onItalic)
                            formatButton(icon: "underline", isActive: isUnderlineActive, action: onUnderline)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 280) // Limit height to stay on screen
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
            }

            // Default buttons (always visible, anchored at bottom)
            VStack(spacing: 2) {
                // Format toggle button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isExpanded ? Color.accentColor.opacity(0.12) : Color.clear)

                        Image(systemName: "textformat")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(isExpanded ? Color.accentColor : Color.primary.opacity(0.5))
                    }
                    .frame(width: buttonSize, height: buttonSize)
                }
                .contentShape(Circle())

                // Keyboard toggle button
                Button(action: onToggleKeyboard) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: iconSize - 1, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: buttonSize, height: buttonSize)
                }
                .contentShape(Circle())
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 6)
        .background(
            ZStack {
                // Glossy background
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)

                // Subtle inner glow/border for glossy effect
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .opacity(isKeyboardVisible ? 1 : 0)
        .scaleEffect(isKeyboardVisible ? 1 : 0.8)
        .onChange(of: isKeyboardVisible) { _, visible in
            if !visible {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded = false
                }
            }
        }
    }

    private func formatButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                }

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.7))
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .contentShape(Circle())
    }

    private func paragraphButton(label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                }

                Text(label)
                    .font(.system(size: label == "¶" ? 18 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.7))
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .contentShape(Circle())
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground)

        HStack {
            Spacer()
            FormattingToolbar(
                onBold: {},
                onItalic: {},
                onUnderline: {},
                onTitle: {},
                onHeading: {},
                onSubheading: {},
                onBody: {},
                onToggleKeyboard: {},
                isKeyboardVisible: true,
                currentStyle: .heading
            )
            .padding()
        }
    }
}
