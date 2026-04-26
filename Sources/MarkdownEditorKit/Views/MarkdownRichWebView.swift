//
//  MarkdownRichWebView.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-25.
//

import SwiftUI
import WebKit

/// Bridges a `WKWebView` running a `contentEditable` HTML editor into SwiftUI
/// for the ``MarkdownEditor`` `.rich` mode.
///
/// The WebView loads a self-contained HTML page that uses `execCommand` for
/// formatting and a DOM-to-Markdown JS traversal to report content changes.
/// Formatting actions from the toolbar are forwarded via
/// `WKWebView.evaluateJavaScript`, so cursor placement and undo/redo are
/// managed entirely by the browser engine — eliminating the hidden-marker
/// cursor-positioning issues of the attribute-based approach.
struct MarkdownRichWebView: UIViewRepresentable {

    @Binding var text: String
    @Binding var isEditing: Bool
    @Binding var activeActions: Set<MarkdownAction>
    @Binding var pendingAction: MarkdownAction?
    @Binding var pendingLinkAction: LinkAction?
    let configuration: MarkdownEditorConfiguration
    let resolvedActions: [MarkdownAction]
    let onImagePick: (() -> Void)?
    let onLinkRequested: ((_ selectedText: String, _ existingURL: String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        let proxy = WeakMessageProxy(target: context.coordinator)
        for name in MessageName.allCases {
            controller.add(proxy, name: name.rawValue)
        }

        let webConfig = WKWebViewConfiguration()
        webConfig.userContentController = controller

        let webView = MarkdownWKWebView(frame: .zero, configuration: webConfig)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        webView.loadHTMLString(MarkdownRichEditorHTML.template, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        // Only push text into the WebView when it changed from outside
        // (not when it came back from the WebView itself via contentChanged).
        if context.coordinator.isLoaded && text != context.coordinator.lastReceivedMarkdown {
            context.coordinator.setContent(text)
        }

        if let action = pendingAction {
            context.coordinator.perform(action)
            // Clear after one run-loop tick to avoid modifying state mid-update.
            DispatchQueue.main.async {
                context.coordinator.parent.pendingAction = nil
            }
        }

        if let action = pendingLinkAction {
            switch action {
            case .insert(let url, let text):
                context.coordinator.insertLink(url: url, text: text)
            case .remove:
                context.coordinator.removeLink()
            }
            DispatchQueue.main.async {
                context.coordinator.parent.pendingLinkAction = nil
            }
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        for name in MessageName.allCases {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name.rawValue)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {

        var parent: MarkdownRichWebView
        weak var webView: WKWebView?
        var isLoaded = false
        var lastReceivedMarkdown = ""

        init(parent: MarkdownRichWebView) {
            self.parent = parent
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            applyStyle(to: webView)
            setContent(parent.text)
        }

        // MARK: Message handling (called by WeakMessageProxy)

        func handle(message: WKScriptMessage) {
            switch message.name {
            case MessageName.contentChanged.rawValue:
                guard let markdown = message.body as? String else { return }
                lastReceivedMarkdown = markdown
                parent.text = markdown

            case MessageName.selectionChanged.rawValue:
                guard let info = message.body as? [String: Bool] else { return }
                var active: Set<MarkdownAction> = []
                if info["bold"] == true         { active.insert(.bold) }
                if info["italic"] == true       { active.insert(.italic) }
                if info["strikethrough"] == true { active.insert(.strikethrough) }
                if info["quote"] == true        { active.insert(.quote) }
                if info["h1"] == true           { active.insert(.heading(level: 1)) }
                if info["h2"] == true           { active.insert(.heading(level: 2)) }
                if info["h3"] == true           { active.insert(.heading(level: 3)) }
                if info["link"] == true         { active.insert(.link) }
                parent.activeActions = active

            case MessageName.focusChanged.rawValue:
                guard let focused = message.body as? Bool else { return }
                parent.isEditing = focused

            case MessageName.linkTapped.rawValue:
                guard let urlString = message.body as? String,
                      let url = LinkURL.normalize(urlString) else { return }
                UIApplication.shared.open(url)

            default: break
            }
        }

        // MARK: Content

        func setContent(_ markdown: String) {
            guard isLoaded, let webView else { return }
            let html = MarkdownToHTML.convert(markdown)
            let escaped = jsEscape(html)
            webView.evaluateJavaScript("setContent('\(escaped)')", completionHandler: nil)
            lastReceivedMarkdown = markdown
        }

        func applyStyle(to webView: WKWebView) {
            let c = parent.configuration
            let fontSize = c.font.pointSize
            let text = cssRGB(c.textColor)
            let secondary = cssRGB(c.syntaxColor)
            webView.evaluateJavaScript(
                "setStyle(\(fontSize), '\(text)', '\(secondary)')",
                completionHandler: nil
            )
        }

        // MARK: Toolbar actions

        func perform(_ action: MarkdownAction) {
            guard let webView else { return }
            let js: String
            switch action {
            case .bold:              js = "applyBold()"
            case .italic:            js = "applyItalic()"
            case .strikethrough:     js = "applyStrikethrough()"
            case .heading(let n):    js = "applyHeading(\(n))"
            case .bulletList:        js = "applyBulletList()"
            case .numberedList:      js = "applyNumberedList()"
            case .taskList:          js = "applyTaskList()"
            case .quote:             js = "applyQuote()"
            case .inlineCode:        js = "applyInlineCode()"
            case .codeBlock:         js = "applyCodeBlock()"
            case .link:              requestLinkSheet(); return
            case .horizontalRule:    js = "insertHR()"
            case .imagePicker:       parent.onImagePick?(); return
            case .image:             requestLinkSheet(); return
            }
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Asks the WebView for the current selection state — a `(text, url)`
        /// pair where `url` is non-empty when the cursor or selection is
        /// inside an existing `<a>`. `prepareLinkSheet` also stashes a JS-side
        /// snapshot of the range so the next `insertLink`/`removeLink` call
        /// can restore it after the sheet has stolen focus.
        private func requestLinkSheet() {
            guard let webView else { return }
            Task { @MainActor in
                let result = try? await webView.evaluateJavaScript("prepareLinkSheet()")
                let info = result as? [String: String] ?? [:]
                let text = info["text"] ?? ""
                let url = info["url"] ?? ""
                self.parent.onLinkRequested?(text, url)
            }
        }

        /// Inserts an `<a href="…">…</a>` into the editor at the selection
        /// captured by the most recent `prepareLinkSheet` call.
        func insertLink(url: String, text: String) {
            guard let webView else { return }
            let escapedURL = jsEscape(url)
            let escapedText = jsEscape(text)
            webView.evaluateJavaScript(
                "applyLink('\(escapedURL)', '\(escapedText)')",
                completionHandler: nil
            )
        }

        /// Unwraps the link captured by the most recent `prepareLinkSheet`,
        /// leaving the link's text in place.
        func removeLink() {
            guard let webView else { return }
            webView.evaluateJavaScript("removeLink()", completionHandler: nil)
        }

        // MARK: Helpers

        private func jsEscape(_ string: String) -> String {
            string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'",  with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
        }

        private func cssRGB(_ color: UIColor) -> String {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return "rgb(\(Int(r*255)),\(Int(g*255)),\(Int(b*255)))"
        }
    }
}

// MARK: - Custom WKWebView

/// Suppresses the native text-formatting bar that iOS shows above the
/// keyboard for `contentEditable` content. MarkdownEditorKit provides its
/// own toolbar, so the system one is redundant.
private final class MarkdownWKWebView: WKWebView {
    override var inputAccessoryView: UIView? { nil }
}

// MARK: - Message names

private enum MessageName: String, CaseIterable {
    case contentChanged
    case selectionChanged
    case focusChanged
    case linkTapped
}

// MARK: - Weak proxy

/// Breaks the retain cycle between `WKUserContentController` (which holds a
/// strong reference to its script message handlers) and the coordinator.
private final class WeakMessageProxy: NSObject, WKScriptMessageHandler {
    weak var target: MarkdownRichWebView.Coordinator?
    init(target: MarkdownRichWebView.Coordinator) { self.target = target }

    func userContentController(_ controller: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        target?.handle(message: message)
    }
}
