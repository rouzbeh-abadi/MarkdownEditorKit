//
//  MarkdownLinkSheet.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-26.
//

import SwiftUI

/// What ``MarkdownEditor`` should do with a confirmed link sheet.
///
/// The rich-mode `WKWebView` consumes this enum via `pendingLinkAction` and
/// translates it into the appropriate JavaScript call.
enum LinkAction: Equatable {
    case insert(url: String, text: String)
    case remove
}

/// Identifiable state used to present ``MarkdownLinkSheet`` via
/// `.sheet(item:)`. A non-empty `initialURL` means the user already has a
/// link selected and the sheet should open in edit mode (with a Remove
/// button and an "Update" confirmation label).
struct LinkSheetData: Identifiable, Equatable {
    let id = UUID()
    var initialText: String
    var initialURL: String

    /// `true` when an existing link is being edited (vs. inserting a new one).
    var isEditing: Bool { !initialURL.isEmpty }
}

/// A modal form that collects a URL and an optional display text from the
/// user and hands the result back to ``MarkdownEditor`` via `onInsert`.
///
/// When `isEditing` is `true` the sheet also surfaces a destructive
/// "Remove Link" button — tapping it dismisses the sheet and triggers
/// `onRemove`, which the host translates into a `removeLink()` call into
/// the WebView.
struct MarkdownLinkSheet: View {

    let initialURL: String
    let initialText: String
    let isEditing: Bool
    let onInsert: (_ url: String, _ text: String) -> Void
    let onRemove: () -> Void

    @State private var url: String
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case url, text }

    init(initialURL: String,
         initialText: String,
         isEditing: Bool,
         onInsert: @escaping (_ url: String, _ text: String) -> Void,
         onRemove: @escaping () -> Void) {
        self.initialURL = initialURL
        self.initialText = initialText
        self.isEditing = isEditing
        self.onInsert = onInsert
        self.onRemove = onRemove
        self._url = State(initialValue: initialURL)
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Note: a URL-shaped placeholder ("https://…") together
                    // with `.textContentType(.URL)` makes iOS render the
                    // placeholder in the system link tint (blue). We use a
                    // plain "URL" prompt here, and set `.tint(.secondary)` so
                    // any link-detected styling falls back to the system
                    // placeholder colour.
                    TextField("URL",
                              text: $url,
                              prompt: Text("URL")
                                  .foregroundStyle(.secondary))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .url)
                        .labelsHidden()
                        .tint(.secondary)
                    TextField("Text",
                              text: $text,
                              prompt: Text("Display text (optional)")
                                  .foregroundStyle(.secondary))
                        .focused($focusedField, equals: .text)
                        .labelsHidden()
                }
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onRemove()
                            dismiss()
                        } label: {
                            Text("Remove Link")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Link" : "Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Insert") {
                        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedURL.isEmpty else { return }
                        onInsert(trimmedURL, trimmedText)
                        dismiss()
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                focusedField = .url
            }
        }
    }
}
