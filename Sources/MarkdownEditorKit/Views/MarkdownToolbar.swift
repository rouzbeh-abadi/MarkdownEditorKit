//
//  MarkdownToolbar.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI

/// A horizontally scrolling strip of formatting buttons that invoke
/// ``MarkdownAction``s.
///
/// `MarkdownToolbar` is used internally by ``MarkdownEditor`` both as the
/// `inputAccessoryView` above the keyboard and as the toolbar shown at the
/// bottom of the editor when the keyboard is dismissed. You can also embed
/// it directly if you want a Markdown toolbar alongside a custom text view.
///
/// Layout metrics (height, button size, icon size, spacing, padding) are
/// driven by the ``Style/toolbar`` passed in, so a custom ``Style`` will
/// reshape the toolbar without any further plumbing.
///
/// ```swift
/// MarkdownToolbar(actions: [.bold, .italic, .link],
///                 style: .default,
///                 onAction: { action in
///                     // Pass the action to your formatter or text view.
///                 })
/// ```
public struct MarkdownToolbar: View {

    private let actions: [MarkdownAction]
    private let style: Style
    private let activeActions: Set<MarkdownAction>
    private let onAction: (MarkdownAction) -> Void

    /// Creates a toolbar.
    ///
    /// - Parameters:
    ///   - actions: The actions to display, in the order they appear.
    ///   - style: Layout metrics for the toolbar. Defaults to
    ///     ``Style/default``.
    ///   - activeActions: The set of actions currently active at the cursor
    ///     position. Active buttons are tinted with the accent color.
    ///   - onAction: A closure invoked with the tapped action.
    public init(actions: [MarkdownAction],
                style: Style = .default,
                activeActions: Set<MarkdownAction> = [],
                onAction: @escaping (MarkdownAction) -> Void) {
        self.actions = actions
        self.style = style
        self.activeActions = activeActions
        self.onAction = onAction
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: style.toolbar.buttonSpacing) {
                ForEach(actions) { action in
                    MarkdownToolbarButton(action: action,
                                          style: style,
                                          isActive: activeActions.contains(action)) {
                        onAction(action)
                    }
                }
            }
            .padding(.horizontal, style.toolbar.horizontalPadding)
            .padding(.vertical, style.toolbar.verticalPadding)
        }
        .frame(height: style.toolbar.height)
        .background(Material.bar, in: RoundedRectangle(cornerRadius: style.toolbar.cornerRadius, style: .continuous))
        .padding(.horizontal, style.toolbar.outerHorizontalPadding)
        .padding(.vertical, style.toolbar.outerVerticalPadding)
    }
}

/// A single button within a ``MarkdownToolbar``.
private struct MarkdownToolbarButton: View {

    let action: MarkdownAction
    let style: Style
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            action.systemImage.image
                .font(.system(size: style.toolbar.iconSize, weight: style.toolbar.iconWeight))
                .frame(width: style.toolbar.buttonSize, height: style.toolbar.buttonSize)
                .background(
                    isActive ? Color.accentColor.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .accessibilityLabel(action.title)
    }
}

#Preview("MarkdownToolbar") {
    MarkdownToolbar(actions: MarkdownEditorConfiguration.defaultActions) { _ in }
}
