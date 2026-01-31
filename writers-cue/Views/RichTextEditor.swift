import SwiftUI
import UIKit

// Formatting state for toolbar
struct FormattingState {
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var currentStyle: TextStyle = .body
}

// Controller to manage typing attributes when no selection
class RichTextEditorController {
    weak var textView: UITextView?
    var onFormattingChange: ((FormattingState) -> Void)?

    func getFormattingState() -> FormattingState {
        guard let textView = textView else { return FormattingState() }

        let attributes: [NSAttributedString.Key: Any]

        // If there's a selection, get attributes from the selected text
        if textView.selectedRange.length > 0 {
            attributes = textView.attributedText.attributes(
                at: textView.selectedRange.location,
                effectiveRange: nil
            )
        } else {
            // No selection, use typing attributes
            attributes = textView.typingAttributes
        }

        let font = attributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
        let traits = font.fontDescriptor.symbolicTraits
        let underline = attributes[.underlineStyle] as? Int ?? 0

        // Check bold by font weight instead of trait to avoid false positives
        // from semibold heading fonts (semibold = 0.3, bold = 0.4)
        var isBold = false
        if let fontTraits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
           let weight = fontTraits[.weight] as? CGFloat {
            isBold = weight >= UIFont.Weight.bold.rawValue
        }

        // Detect current text style from font size
        let currentStyle = TextStyle.detect(from: font)

        return FormattingState(
            isBold: isBold,
            isItalic: traits.contains(.traitItalic),
            isUnderline: underline > 0,
            currentStyle: currentStyle
        )
    }

    func notifyFormattingChange() {
        let state = getFormattingState()
        onFormattingChange?(state)
    }

    func toggleBoldTyping() {
        guard let textView = textView else { return }
        var attributes = textView.typingAttributes
        let currentFont = attributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)

        if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
            attributes[.font] = currentFont.withoutTraits(.traitBold)
        } else {
            attributes[.font] = currentFont.withTraits(.traitBold)
        }
        textView.typingAttributes = attributes
        notifyFormattingChange()
    }

    func toggleItalicTyping() {
        guard let textView = textView else { return }
        var attributes = textView.typingAttributes
        let currentFont = attributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)

        if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
            attributes[.font] = currentFont.withoutTraits(.traitItalic)
        } else {
            attributes[.font] = currentFont.withTraits(.traitItalic)
        }
        textView.typingAttributes = attributes
        notifyFormattingChange()
    }

    func toggleUnderlineTyping() {
        guard let textView = textView else { return }
        var attributes = textView.typingAttributes
        let currentUnderline = attributes[.underlineStyle] as? Int ?? 0

        if currentUnderline > 0 {
            attributes.removeValue(forKey: .underlineStyle)
        } else {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        textView.typingAttributes = attributes
        notifyFormattingChange()
    }

    func setStyleForTyping(_ style: TextStyle, isDarkMode: Bool) {
        guard let textView = textView else { return }
        var attributes = textView.typingAttributes
        let styleAttributes = style.attributes(isDarkMode: isDarkMode)

        for (key, value) in styleAttributes {
            attributes[key] = value
        }
        textView.typingAttributes = attributes
        notifyFormattingChange()
    }

    func getCurrentStyle() -> TextStyle {
        guard let textView = textView else { return .body }
        let font = textView.typingAttributes[.font] as? UIFont
        return TextStyle.detect(from: font)
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    var onTextChange: () -> Void
    var onKeyboardChange: ((Bool, CGFloat) -> Void)?  // (isVisible, keyboardHeight)
    var controller: RichTextEditorController?
    var textColor: UIColor = .label
    var tintColor: UIColor = .tintColor
    var isDarkMode: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.allowsEditingTextAttributes = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 24, bottom: 40, right: 24)
        textView.textColor = textColor
        textView.tintColor = tintColor

        // Initialize typing attributes with body style for consistent paragraph spacing
        textView.typingAttributes = TextStyle.body.attributes(isDarkMode: isDarkMode)

        // Setup keyboard observers
        context.coordinator.setupKeyboardObservers(for: textView)

        // Connect controller
        controller?.textView = textView

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText != attributedText {
            let currentSelectedRange = textView.selectedRange
            textView.attributedText = attributedText
            textView.selectedRange = currentSelectedRange
        }
        textView.textColor = textColor
        textView.tintColor = tintColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        private weak var textView: UITextView?
        private var savedTypingAttributes: [NSAttributedString.Key: Any]?

        // For line merge formatting: stores info when deleting a newline
        private var lineMergeInfo: LineMergeInfo?

        struct LineMergeInfo {
            let destinationStyle: TextStyle       // Style of the line we're merging INTO
            let mergePosition: Int                // Position where the merge occurs
            let sourceLineLength: Int             // Length of the source line content being merged
        }

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func setupKeyboardObservers(for textView: UITextView) {
            self.textView = textView

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }

        @objc private func keyboardWillShow(_ notification: Notification) {
            guard let textView = textView,
                  let userInfo = notification.userInfo,
                  let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            let keyboardHeight = keyboardFrame.height
            let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight + 2, right: 0)
            textView.contentInset = contentInset
            textView.scrollIndicatorInsets = contentInset

            // Scroll to cursor
            scrollToCursor(textView)

            // Notify parent of keyboard visibility and height
            DispatchQueue.main.async {
                self.parent.onKeyboardChange?(true, keyboardHeight)
            }
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            guard let textView = textView else { return }

            textView.contentInset = .zero
            textView.scrollIndicatorInsets = .zero

            // Notify parent of keyboard visibility
            DispatchQueue.main.async {
                self.parent.onKeyboardChange?(false, 0)
            }
        }

        private func scrollToCursor(_ textView: UITextView) {
            if let selectedRange = textView.selectedTextRange {
                let caretRect = textView.caretRect(for: selectedRange.end)
                textView.scrollRectToVisible(caretRect, animated: true)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Handle line merge formatting - apply destination line's style to merged content
            if let mergeInfo = lineMergeInfo {
                lineMergeInfo = nil
                savedTypingAttributes = nil  // Clear saved attrs since we're handling formatting

                // Apply the destination line's formatting to the entire merged line
                let nsString = textView.attributedText.string as NSString
                if mergeInfo.mergePosition < nsString.length {
                    // Get the full line range after the merge
                    let lineRange = nsString.lineRange(for: NSRange(location: mergeInfo.mergePosition, length: 0))

                    // Apply the destination style to the entire line
                    let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
                    let styleAttributes = mergeInfo.destinationStyle.attributes(isDarkMode: parent.isDarkMode)

                    for (key, value) in styleAttributes {
                        mutableText.addAttribute(key, value: value, range: lineRange)
                    }

                    // Preserve cursor position
                    let currentSelection = textView.selectedRange
                    textView.attributedText = mutableText

                    // Restore cursor position
                    if currentSelection.location <= mutableText.length {
                        textView.selectedRange = currentSelection
                    }

                    // Update typing attributes to match the destination style
                    var typingAttrs = textView.typingAttributes
                    for (key, value) in styleAttributes {
                        typingAttrs[key] = value
                    }
                    textView.typingAttributes = typingAttrs

                    parent.controller?.notifyFormattingChange()
                }
            } else if let savedAttrs = savedTypingAttributes {
                // Restore saved typing attributes after regular deletion (no line merge)
                textView.typingAttributes = savedAttrs
                savedTypingAttributes = nil
                parent.controller?.notifyFormattingChange()
            }

            parent.attributedText = textView.attributedText
            parent.onTextChange()

            // Scroll to cursor after text changes
            scrollToCursor(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange

            // Sync typing attributes with the style at current cursor position
            // This ensures new text/newlines use the correct paragraph style
            syncTypingAttributesWithCursorPosition(textView)

            // Notify about formatting state change
            parent.controller?.notifyFormattingChange()
        }

        /// Syncs typing attributes to match the style at the current cursor position
        private func syncTypingAttributesWithCursorPosition(_ textView: UITextView) {
            let location = textView.selectedRange.location
            let length = textView.attributedText.length

            guard length > 0 else { return }

            // Determine which position to get style from
            let checkLocation: Int
            if location == 0 {
                checkLocation = 0
            } else if location >= length {
                checkLocation = length - 1
            } else {
                // When cursor is between characters, use the character to the left
                checkLocation = location - 1
            }

            // Get the style at that position
            let style = TextFormatter.styleAt(location: checkLocation, in: textView.attributedText)
            let styleAttributes = style.attributes(isDarkMode: parent.isDarkMode)

            // Merge style attributes into typing attributes (preserving bold/italic/underline)
            var typingAttrs = textView.typingAttributes

            // Preserve font traits (bold/italic) from current typing attributes
            let currentFont = typingAttrs[.font] as? UIFont
            var newFont = styleAttributes[.font] as! UIFont

            if let currentFont = currentFont {
                let traits = currentFont.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    newFont = newFont.withTraits(.traitBold)
                }
                if traits.contains(.traitItalic) {
                    newFont = newFont.withTraits(.traitItalic)
                }
            }

            typingAttrs[.font] = newFont
            typingAttrs[.foregroundColor] = styleAttributes[.foregroundColor]
            typingAttrs[.paragraphStyle] = styleAttributes[.paragraphStyle]

            textView.typingAttributes = typingAttrs
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Clear any previous merge info
            lineMergeInfo = nil

            // Handle deletion - check for line merge (backspace/delete across newline)
            if text.isEmpty && range.length > 0 {
                let nsString = textView.attributedText.string as NSString
                let deletedText = nsString.substring(with: range)

                // Check if we're deleting a newline (merging lines)
                if deletedText.contains("\n") {
                    // Find the destination line (line before the newline)
                    // and the source line (line after the newline)
                    let newlineIndex = (deletedText as NSString).range(of: "\n").location
                    let absoluteNewlinePos = range.location + newlineIndex

                    // Get the style of the destination line (what we're merging INTO)
                    if absoluteNewlinePos > 0 {
                        let destinationStyle = TextFormatter.styleAt(
                            location: absoluteNewlinePos - 1,
                            in: textView.attributedText
                        )

                        // Calculate the range of content that will be merged from the source line
                        // After the newline to the end of the deletion range, plus any remaining source line content
                        let afterNewline = absoluteNewlinePos + 1
                        if afterNewline < nsString.length {
                            // Find the end of the source line
                            let sourceLineRange = nsString.lineRange(for: NSRange(location: afterNewline, length: 0))
                            let sourceLineLength = sourceLineRange.length - (afterNewline - sourceLineRange.location)

                            // Save merge info for use in textViewDidChange
                            lineMergeInfo = LineMergeInfo(
                                destinationStyle: destinationStyle,
                                mergePosition: absoluteNewlinePos - newlineIndex, // Where merged content will start
                                sourceLineLength: max(0, sourceLineLength)
                            )
                        }
                    }
                }

                // Save current typing attributes before deletion
                savedTypingAttributes = textView.typingAttributes
            }

            // Check if user is inserting a newline
            if text == "\n" {
                // Get the style at the current position
                let location = range.location
                if location > 0 && location <= textView.attributedText.length {
                    let checkLocation = min(location - 1, textView.attributedText.length - 1)
                    if checkLocation >= 0 {
                        let font = textView.attributedText.attribute(.font, at: checkLocation, effectiveRange: nil) as? UIFont
                        let currentStyle = TextStyle.detect(from: font)

                        // If current line is a heading style, manually insert newline with body style
                        // This ensures consistent paragraph spacing for the new line
                        if currentStyle == .title || currentStyle == .heading || currentStyle == .subheading {
                            // Create body attributes for the new line
                            let bodyAttributes = TextStyle.body.attributes(isDarkMode: self.parent.isDarkMode)

                            // Create newline with body paragraph style (reset bold/italic for new paragraph)
                            let newlineString = NSAttributedString(string: "\n", attributes: bodyAttributes)

                            // Build the new attributed string
                            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                            mutable.replaceCharacters(in: range, with: newlineString)

                            // Update the text view
                            textView.attributedText = mutable

                            // Set cursor position after the newline
                            let newCursorPosition = range.location + 1
                            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)

                            // Update typing attributes for subsequent typing (merge to preserve underline if set)
                            var typingAttrs = textView.typingAttributes
                            for (key, value) in bodyAttributes {
                                typingAttrs[key] = value
                            }
                            // Reset bold/italic for new paragraph after heading
                            typingAttrs[.font] = bodyAttributes[.font]
                            textView.typingAttributes = typingAttrs

                            // Notify about the change
                            parent.attributedText = textView.attributedText
                            parent.onTextChange()
                            parent.controller?.notifyFormattingChange()

                            // Return false since we handled the insertion manually
                            return false
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Typography System

enum TextStyle: String, CaseIterable {
    case title      // H1 - Document title, main heading
    case heading    // H2 - Section headings
    case subheading // H3 - Subsections
    case body       // Body text
    case caption    // Small text, metadata

    var fontSize: CGFloat {
        switch self {
        case .title: return 28
        case .heading: return 22
        case .subheading: return 18
        case .body: return 17
        case .caption: return 14
        }
    }

    var fontWeight: UIFont.Weight {
        switch self {
        case .title: return .light
        case .heading: return .semibold
        case .subheading: return .semibold
        case .body: return .regular
        case .caption: return .regular
        }
    }

    var lineHeightMultiple: CGFloat {
        switch self {
        case .title: return 1.2
        case .heading: return 1.25
        case .subheading: return 1.25
        case .body: return 1.2
        case .caption: return 1.2
        }
    }

    var paragraphSpacingBefore: CGFloat {
        switch self {
        case .title: return 0
        case .heading: return 8
        case .subheading: return 6
        case .body: return 0
        case .caption: return 4
        }
    }

    var paragraphSpacingAfter: CGFloat {
        switch self {
        case .title: return 16
        case .heading: return 8
        case .subheading: return 6
        case .body: return 0
        case .caption: return 4
        }
    }

    func font() -> UIFont {
        UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
    }

    func color(isDarkMode: Bool) -> UIColor {
        switch self {
        case .title:
            return isDarkMode ? ThemeColors.darkUITitleColor : ThemeColors.lightUITitleColor
        case .heading:
            return isDarkMode ? ThemeColors.darkUIHeadingColor : ThemeColors.lightUIHeadingColor
        case .subheading:
            return isDarkMode ? ThemeColors.darkUISubheadingColor : ThemeColors.lightUISubheadingColor
        case .body:
            return isDarkMode ? ThemeColors.darkUIBodyColor : ThemeColors.lightUIBodyColor
        case .caption:
            return isDarkMode ? UIColor(hex: "9A9A9A") : UIColor(hex: "6B6B6B")
        }
    }

    func paragraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.paragraphSpacingBefore = paragraphSpacingBefore
        style.paragraphSpacing = paragraphSpacingAfter
        return style
    }

    func attributes(isDarkMode: Bool) -> [NSAttributedString.Key: Any] {
        return [
            .font: font(),
            .foregroundColor: color(isDarkMode: isDarkMode),
            .paragraphStyle: paragraphStyle()
        ]
    }

    // Detect style from font size
    static func detect(from font: UIFont?) -> TextStyle {
        guard let font = font else { return .body }
        let size = font.pointSize

        if size >= 26 { return .title }
        if size >= 20 { return .heading }
        if size >= 18 { return .subheading }
        if size <= 15 { return .caption }
        return .body
    }
}

class TextFormatter {
    static var isDarkMode: Bool = false

    static func toggleBold(in attributedString: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributedString }

        let mutable = NSMutableAttributedString(attributedString: attributedString)
        var isBold = false

        if range.location < attributedString.length {
            if let font = attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            }
        }

        let currentFont = (attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        let newFont: UIFont

        if isBold {
            newFont = currentFont.withoutTraits(.traitBold)
        } else {
            newFont = currentFont.withTraits(.traitBold)
        }

        mutable.addAttribute(.font, value: newFont, range: range)
        return mutable
    }

    static func toggleItalic(in attributedString: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributedString }

        let mutable = NSMutableAttributedString(attributedString: attributedString)
        var isItalic = false

        if range.location < attributedString.length {
            if let font = attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            }
        }

        let currentFont = (attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        let newFont: UIFont

        if isItalic {
            newFont = currentFont.withoutTraits(.traitItalic)
        } else {
            newFont = currentFont.withTraits(.traitItalic)
        }

        mutable.addAttribute(.font, value: newFont, range: range)
        return mutable
    }

    static func toggleUnderline(in attributedString: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributedString }

        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let currentUnderline = attributedString.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0

        if currentUnderline > 0 {
            mutable.removeAttribute(.underlineStyle, range: range)
        } else {
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        return mutable
    }

    static func applyStyle(_ style: TextStyle, in attributedString: NSAttributedString, range: NSRange) -> NSAttributedString {
        let string = attributedString.string as NSString
        guard string.length > 0 else {
            // Empty document - return styled empty string
            let mutable = NSMutableAttributedString(string: "")
            return mutable
        }

        guard range.location <= string.length else { return attributedString }

        // Expand to full line(s) containing the selection/cursor
        let safeLocation = min(range.location, string.length - 1)
        let safeRange = NSRange(location: safeLocation, length: min(range.length, string.length - safeLocation))
        let lineRange = string.lineRange(for: safeRange)

        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let attributes = style.attributes(isDarkMode: isDarkMode)

        // Apply all typography attributes
        for (key, value) in attributes {
            mutable.addAttribute(key, value: value, range: lineRange)
        }

        return mutable
    }

    // Get the style of text at a given location
    static func styleAt(location: Int, in attributedString: NSAttributedString) -> TextStyle {
        guard location < attributedString.length else { return .body }
        let font = attributedString.attribute(.font, at: location, effectiveRange: nil) as? UIFont
        return TextStyle.detect(from: font)
    }
}

// MARK: - UIFont Extension

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    func withoutTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.subtracting(traits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
