//
//  MarkdownTextView.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI
import UIKit

/// Bridges a `UITextView` into SwiftUI for ``MarkdownEditor``.
///
/// The view manages three concerns:
///
/// 1. Two-way binding between the editor's text and the underlying text
///    view, with an additional selection binding so toolbar actions can
///    operate on the caret / highlighted range.
/// 2. Syntax highlighting via ``MarkdownSyntaxHighlighter``, re-applied
///    after every edit.
/// 3. An `inputAccessoryView` hosting a ``MarkdownToolbar``, so formatting
///    buttons appear above the keyboard while the user is editing.
///
/// Changes to the ``MarkdownEditorConfiguration`` — fonts, colors, layout
/// style, toolbar visibility, or the enabled action set — are picked up
/// live: when the host passes a new configuration, the existing text view
/// re-syncs its appearance and reinstalls its accessory toolbar, so
/// runtime theme changes take effect without re-creating the editor.
///
/// This type is intentionally internal: users interact with
/// ``MarkdownEditor`` instead, which composes this view with a secondary
/// toolbar shown when the keyboard is dismissed.
struct MarkdownTextView: UIViewRepresentable {

    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var isEditing: Bool
    @Binding var activeActions: Set<MarkdownAction>
    let configuration: MarkdownEditorConfiguration
    let resolvedActions: [MarkdownAction]
    let hidesMarkers: Bool
    let onImagePick: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = MarkdownRichTextView()
        textView.delegate = context.coordinator
        textView.alwaysBounceVertical = true
        textView.allowsEditingTextAttributes = false
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardDismissMode = .interactive

        context.coordinator.textView = textView
        context.coordinator.applyConfiguration(to: textView)
        textView.text = text
        context.coordinator.applyHighlightingIfNeeded()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        let configurationChanged = context.coordinator.syncConfigurationIfNeeded(to: uiView)

        var textChanged = false
        if uiView.text != text {
            let previous = uiView.selectedRange
            uiView.text = text
            uiView.selectedRange = MarkdownFormatter.clamp(previous, length: (text as NSString).length)
            textChanged = true
        }

        if configurationChanged || textChanged {
            context.coordinator.applyHighlightingIfNeeded()
        }

        let desired = MarkdownFormatter.clamp(selection, length: (uiView.text as NSString).length)
        if !NSEqualRanges(uiView.selectedRange, desired) {
            uiView.selectedRange = desired
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Manages the UITextView delegate callbacks, highlighting, and the
    /// hosted input-accessory toolbar.
    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {

        var parent: MarkdownTextView
        weak var textView: UITextView?

        private var accessoryHost: UIHostingController<MarkdownToolbar>?
        private var lastActions: [MarkdownAction]?
        private var lastShowsToolbar: Bool?
        private var lastToolbarStyle: Style.Toolbar?
        private var lastFont: UIFont?
        private var lastTextColor: UIColor?
        private var lastBackground: UIColor?
        private var lastContentInsets: UIEdgeInsets?
        private var lastHandlesImagePick: Bool?
        private var lastHidesMarkers: Bool?
        private var isApplyingHighlighting = false

        init(parent: MarkdownTextView) {
            self.parent = parent
        }

        // MARK: Configuration

        /// Applies the current configuration to `uiView` unconditionally.
        ///
        /// Used at creation time, before any diff baseline exists.
        func applyConfiguration(to uiView: UITextView) {
            let config = parent.configuration
            uiView.font = config.font
            uiView.textColor = config.textColor
            uiView.backgroundColor = config.backgroundColor
            uiView.textContainerInset = config.style.textView.contentInsets
            if let rich = uiView as? MarkdownRichTextView {
                rich.drawsHorizontalRules = parent.hidesMarkers
                rich.horizontalRuleColor = config.syntaxColor
                rich.richBodyFont = config.font
                rich.richTextColor = config.textColor
            }
            installAccessoryIfNeeded()
            lastFont = config.font
            lastTextColor = config.textColor
            lastBackground = config.backgroundColor
            lastContentInsets = config.style.textView.contentInsets
            lastActions = parent.resolvedActions
            lastShowsToolbar = config.showsToolbar
            lastToolbarStyle = config.style.toolbar
            lastHandlesImagePick = parent.onImagePick != nil
            lastHidesMarkers = parent.hidesMarkers
        }

        /// Re-applies the configuration when any visible property has
        /// changed since the last sync.
        ///
        /// - Returns: `true` if the configuration changed and the caller
        ///   should re-run syntax highlighting.
        @discardableResult
        func syncConfigurationIfNeeded(to uiView: UITextView) -> Bool {
            let config = parent.configuration
            let actions = parent.resolvedActions
            let handlesImagePick = parent.onImagePick != nil

            let appearanceChanged = lastFont != config.font
                || lastTextColor != config.textColor
                || lastBackground != config.backgroundColor
                || lastContentInsets != config.style.textView.contentInsets
                || lastHidesMarkers != parent.hidesMarkers
            let toolbarChanged = lastShowsToolbar != config.showsToolbar
                || lastActions != actions
                || lastToolbarStyle != config.style.toolbar
                || lastHandlesImagePick != handlesImagePick

            guard appearanceChanged || toolbarChanged else { return false }

            uiView.font = config.font
            uiView.textColor = config.textColor
            uiView.backgroundColor = config.backgroundColor
            uiView.textContainerInset = config.style.textView.contentInsets
            if let rich = uiView as? MarkdownRichTextView {
                rich.drawsHorizontalRules = parent.hidesMarkers
                rich.horizontalRuleColor = config.syntaxColor
                rich.richBodyFont = config.font
                rich.richTextColor = config.textColor
            }

            if toolbarChanged {
                installAccessoryIfNeeded()
            }

            lastFont = config.font
            lastTextColor = config.textColor
            lastBackground = config.backgroundColor
            lastContentInsets = config.style.textView.contentInsets
            lastActions = actions
            lastShowsToolbar = config.showsToolbar
            lastToolbarStyle = config.style.toolbar
            lastHandlesImagePick = handlesImagePick
            lastHidesMarkers = parent.hidesMarkers
            return appearanceChanged
        }

        // MARK: Input accessory

        func installAccessoryIfNeeded() {
            guard let textView else { return }

            guard parent.configuration.showsToolbar else {
                textView.inputAccessoryView = nil
                accessoryHost = nil
                textView.reloadInputViews()
                return
            }

            let toolbar = MarkdownToolbar(actions: parent.resolvedActions,
                                          style: parent.configuration.style,
                                          onAction: { [weak self] action in
                                              self?.perform(action)
                                          })
            let host = AccessoryHostingController(rootView: toolbar)
            host.view.backgroundColor = .clear
            host.view.autoresizingMask = [.flexibleWidth]
            let width = UIScreen.main.bounds.width
            let toolbarStyle = parent.configuration.style.toolbar
            let height = toolbarStyle.height + 2 * toolbarStyle.outerVerticalPadding
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            textView.inputAccessoryView = host.view
            accessoryHost = host
            textView.reloadInputViews()
        }

        // MARK: Formatting

        func perform(_ action: MarkdownAction) {
            if action == .imagePicker {
                parent.onImagePick?()
                return
            }
            guard let textView else { return }
            let result = MarkdownFormatter.apply(action,
                                                 to: textView.text ?? "",
                                                 in: textView.selectedRange)
            textView.text = result.text
            textView.selectedRange = result.selection
            parent.text = result.text
            parent.selection = result.selection
            applyHighlightingIfNeeded()
        }

        // MARK: Highlighting

        func applyHighlightingIfNeeded() {
            guard parent.configuration.highlightsSyntax, let textView else { return }
            isApplyingHighlighting = true
            defer { isApplyingHighlighting = false }

            let style = MarkdownSyntaxHighlighter.Style(bodyFont: parent.configuration.font,
                                                        monospacedFont: parent.configuration.monospacedFont,
                                                        textColor: parent.configuration.textColor,
                                                        syntaxColor: parent.configuration.syntaxColor,
                                                        hidesMarkers: parent.hidesMarkers)
            let highlighter = MarkdownSyntaxHighlighter(style: style)
            let selected = textView.selectedRange
            let attributed = highlighter.highlight(textView.text ?? "")
            textView.attributedText = attributed
            textView.selectedRange = MarkdownFormatter.clamp(selected,
                                                             length: (textView.text as NSString).length)
            textView.typingAttributes = [
                .font: parent.configuration.font,
                .foregroundColor: parent.configuration.textColor,
            ]
            if let rich = textView as? MarkdownRichTextView {
                rich.setNeedsRuleOverlayUpdate()
            }
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingHighlighting else { return }
            applyHighlightingIfNeeded()
            let newText = textView.text ?? ""
            let newSelection = textView.selectedRange
            deferToNextRunLoop { [weak self] in
                guard let self else { return }
                if self.parent.text != newText {
                    self.parent.text = newText
                }
                if !NSEqualRanges(self.parent.selection, newSelection) {
                    self.parent.selection = newSelection
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingHighlighting else { return }
            let newSelection = textView.selectedRange
            let newActive = computeActiveActions(in: textView)
            updateAccessoryActiveActions(newActive)
            deferToNextRunLoop { [weak self] in
                guard let self else { return }
                if !NSEqualRanges(self.parent.selection, newSelection) {
                    self.parent.selection = newSelection
                }
                if self.parent.activeActions != newActive {
                    self.parent.activeActions = newActive
                }
            }
        }

        private func computeActiveActions(in textView: UITextView) -> Set<MarkdownAction> {
            let text = textView.text ?? ""
            let nsText = text as NSString
            let length = nsText.length
            guard length > 0, let attributed = textView.attributedText else { return [] }

            let pos = textView.selectedRange.location
            let attrPos = pos > 0 ? min(pos - 1, length - 1) : 0
            var active: Set<MarkdownAction> = []

            let attrs = attributed.attributes(at: attrPos, effectiveRange: nil)
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { active.insert(.bold) }
                if traits.contains(.traitItalic) { active.insert(.italic) }
            }
            if attrs[.strikethroughStyle] != nil { active.insert(.strikethrough) }

            let clampedPos = min(pos, length - 1)
            let lineRange = nsText.lineRange(for: NSRange(location: clampedPos, length: 0))
            let prefixLen = min(lineRange.length, 40)
            if prefixLen > 0 {
                let line = nsText.substring(with: NSRange(location: lineRange.location, length: prefixLen))
                if line.hasPrefix("> ") { active.insert(.quote) }
                if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                    active.insert(.taskList)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                    active.insert(.bulletList)
                } else if let firstChar = line.first, firstChar.isNumber, line.contains(". ") {
                    active.insert(.numberedList)
                }
            }

            return active
        }

        private func updateAccessoryActiveActions(_ active: Set<MarkdownAction>) {
            guard let accessoryHost else { return }
            accessoryHost.rootView = MarkdownToolbar(actions: parent.resolvedActions,
                                                      style: parent.configuration.style,
                                                      activeActions: active,
                                                      onAction: { [weak self] action in
                                                          self?.perform(action)
                                                      })
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            deferToNextRunLoop { [weak self] in
                self?.parent.isEditing = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            deferToNextRunLoop { [weak self] in
                self?.parent.isEditing = false
            }
        }

        /// Schedules a SwiftUI binding write for the next main-queue turn.
        ///
        /// UITextView's delegate callbacks can fire while SwiftUI is mid
        /// view-update (for example, during layout triggered by a nested
        /// `attributedText` assignment). Writing to `@Binding` synchronously
        /// in that window trips SwiftUI's "modifying state during view
        /// update" runtime warning, so we defer every binding write by a
        /// run-loop tick.
        private func deferToNextRunLoop(_ work: @escaping @MainActor () -> Void) {
            DispatchQueue.main.async { work() }
        }
    }

    /// A hosting controller that refuses first-responder status so hosting
    /// the SwiftUI toolbar as an `inputAccessoryView` never steals the
    /// keyboard focus from the text view.
    private final class AccessoryHostingController<Content: View>: UIHostingController<Content> {
        override var canBecomeFirstResponder: Bool { false }
    }
}

/// A `UITextView` subclass that can paint full-width horizontal rules on
/// top of `^---$` lines while editing.
///
/// Rich mode renders the three raw `-` glyphs transparently to preserve
/// the line's vertical height, then this view draws a 1 pt line across
/// the full content width at the line's vertical midpoint. Drawing on a
/// dedicated overlay subview (rather than through attribute runs) is the
/// only way to span the container edges regardless of how the three
/// hyphens would measure at a given font size.
final class MarkdownRichTextView: UITextView {

    /// The body font used when resetting typing attributes. Must match
    /// `MarkdownEditorConfiguration.font` so new characters after hidden
    /// markers inherit the correct size rather than the zero-size hidden font.
    var richBodyFont: UIFont = .preferredFont(forTextStyle: .body)

    /// The text color used when resetting typing attributes.
    var richTextColor: UIColor = .label

    /// When `true`, paragraphs matching `^---$` are painted as a
    /// full-width overlay line. When `false`, the overlay is hidden.
    var drawsHorizontalRules: Bool = false {
        didSet {
            overlay.isHidden = !drawsHorizontalRules
            setNeedsRuleOverlayUpdate()
        }
    }

    /// The color used for the overlay rule.
    var horizontalRuleColor: UIColor = .separator {
        didSet { setNeedsRuleOverlayUpdate() }
    }

    private lazy var overlay: RuleOverlayView = {
        let view = RuleOverlayView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isHidden = true
        view.textView = self
        addSubview(view)
        return view
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        _ = overlay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _ = overlay
    }

    /// Prevents UITextView from inheriting a zero-size font when the cursor
    /// sits adjacent to a hidden marker character. Without this, pressing
    /// Enter after `**bold**` would start the new line with an invisible font.
    override var typingAttributes: [NSAttributedString.Key: Any] {
        get {
            var attrs = super.typingAttributes
            if let font = attrs[.font] as? UIFont, font.pointSize < 1 {
                attrs[.font] = richBodyFont
                attrs[.foregroundColor] = richTextColor
            }
            return attrs
        }
        set { super.typingAttributes = newValue }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlay.frame = CGRect(origin: .zero, size: contentSize)
        bringSubviewToFront(overlay)
        overlay.updateRules()
    }

    /// Requests that the overlay recompute its rule positions. Call this
    /// after changing `attributedText`, since the new layout may have
    /// moved or added `---` paragraphs.
    func setNeedsRuleOverlayUpdate() {
        setNeedsLayout()
    }
}

/// A transparent overlay that draws horizontal-rule lines on top of its
/// host text view. Holds a `CAShapeLayer` path recomputed whenever the
/// host's layout or text content changes.
private final class RuleOverlayView: UIView {

    weak var textView: MarkdownRichTextView?

    private let shape: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 1
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(shape)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
    }

    func updateRules() {
        guard let textView, textView.drawsHorizontalRules else {
            shape.path = nil
            return
        }
        let text = textView.text ?? ""
        guard let regex = try? NSRegularExpression(pattern: "^-{3,}$",
                                                    options: .anchorsMatchLines) else {
            shape.path = nil
            return
        }

        let inset = textView.textContainerInset
        let left = inset.left
        let right = textView.bounds.width - inset.right
        guard right > left else {
            shape.path = nil
            return
        }

        let path = UIBezierPath()
        let full = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match,
                  let start = textView.position(from: textView.beginningOfDocument,
                                                 offset: match.range.location),
                  let end = textView.position(from: start, offset: match.range.length),
                  let range = textView.textRange(from: start, to: end)
            else { return }
            let rect = textView.firstRect(for: range)
            guard rect.height.isFinite, rect.origin.y.isFinite, !rect.isNull, rect.height > 0 else {
                return
            }
            let y = rect.midY
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }

        shape.path = path.cgPath
        shape.strokeColor = textView.horizontalRuleColor.cgColor
    }
}
