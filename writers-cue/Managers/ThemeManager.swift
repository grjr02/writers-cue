import SwiftUI

enum AppTheme: String, CaseIterable {
    case light
    case dark
    case auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }
}

struct ThemeColors {
    let canvasBackground: Color
    let textColor: Color
    let accentColor: Color

    // Typography colors
    let titleColor: Color         // H1 - muted
    let headingColor: Color       // H2
    let subheadingColor: Color    // H3
    let bodyColor: Color          // Body text
    let captionColor: Color       // Small text, metadata
    let placeholderColor: Color   // Empty state text

    static let light = ThemeColors(
        canvasBackground: Color(hex: "F6F3EE"),
        textColor: Color(hex: "1F1F1F"),
        accentColor: Color(hex: "D6DEE6"),
        titleColor: Color(hex: "5C5C5C"),
        headingColor: Color(hex: "3D3D3D"),
        subheadingColor: Color(hex: "4A4A4A"),
        bodyColor: Color(hex: "1F1F1F"),
        captionColor: Color(hex: "6B6B6B"),
        placeholderColor: Color(hex: "AAAAAA")
    )

    static let dark = ThemeColors(
        canvasBackground: Color(hex: "1B1B1B"),
        textColor: Color(hex: "E6E6E6"),
        accentColor: Color(hex: "9CAAAF"),
        titleColor: Color(hex: "A0A0A0"),
        headingColor: Color(hex: "D0D0D0"),
        subheadingColor: Color(hex: "BEBEBE"),
        bodyColor: Color(hex: "E6E6E6"),
        captionColor: Color(hex: "9A9A9A"),
        placeholderColor: Color(hex: "555555")
    )
}

@Observable
class ThemeManager {
    static let shared = ThemeManager()

    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }

    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }

    var colors: ThemeColors {
        switch selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            // This will be resolved at runtime based on system setting
            return .light // Default, actual will be determined by view
        }
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .auto
        }
    }

    func colors(for colorScheme: ColorScheme) -> ThemeColors {
        switch selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return colorScheme == .dark ? .dark : .light
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor Extension for Hex

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - UIColor Theme Colors

extension ThemeColors {
    var uiTextColor: UIColor {
        UIColor(textColor)
    }

    var uiAccentColor: UIColor {
        UIColor(accentColor)
    }

    var uiTitleColor: UIColor {
        UIColor(titleColor)
    }

    var uiHeadingColor: UIColor {
        UIColor(headingColor)
    }

    var uiSubheadingColor: UIColor {
        UIColor(subheadingColor)
    }

    var uiBodyColor: UIColor {
        UIColor(bodyColor)
    }

    var uiCaptionColor: UIColor {
        UIColor(captionColor)
    }

    var uiPlaceholderColor: UIColor {
        UIColor(placeholderColor)
    }

    static let lightUITextColor = UIColor(hex: "1F1F1F")
    static let darkUITextColor = UIColor(hex: "E6E6E6")
    static let lightUIAccentColor = UIColor(hex: "D6DEE6")
    static let darkUIAccentColor = UIColor(hex: "9CAAAF")

    // Typography UIColors
    static let lightUITitleColor = UIColor(hex: "5C5C5C")
    static let darkUITitleColor = UIColor(hex: "A0A0A0")
    static let lightUIHeadingColor = UIColor(hex: "3D3D3D")
    static let darkUIHeadingColor = UIColor(hex: "D0D0D0")
    static let lightUISubheadingColor = UIColor(hex: "4A4A4A")
    static let darkUISubheadingColor = UIColor(hex: "BEBEBE")
    static let lightUIBodyColor = UIColor(hex: "1F1F1F")
    static let darkUIBodyColor = UIColor(hex: "E6E6E6")
}
