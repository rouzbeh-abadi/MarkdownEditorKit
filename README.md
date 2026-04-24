# MarkdownEditorKit

A SwiftUI Markdown editor with inline syntax highlighting and a keyboard-accessory formatting toolbar, built on top of `UITextView`.

## Features

- Drop-in SwiftUI view: `MarkdownEditor(text: $markdown)`.
- Live Markdown syntax highlighting while you type — headings, emphasis, lists, quotes, inline and fenced code, and links.
- Formatting toolbar above the keyboard while editing, and at the bottom of the editor when the keyboard is dismissed.
- Customisable action set, fonts, and colors via `MarkdownEditorConfiguration`.
- A pure, testable `MarkdownFormatter` you can drive from your own UI.

## Requirements

- iOS 17+
- Swift 6.0+ (Swift 6 language mode)
- Xcode 16+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rouzbeh-abadi/MarkdownEditorKit.git", from: "1.0.0")
]
```

…and to your target:

```swift
.target(name: "YourApp",
        dependencies: ["MarkdownEditorKit"])
```

Or, in Xcode, choose **File → Add Package Dependencies…** and enter the repository URL.

## Usage

### Basic editor

```swift
import SwiftUI
import MarkdownEditorKit

struct NoteEditorView: View {
    @State private var markdown = "# Notes\n\nStart writing…"

    var body: some View {
        MarkdownEditor(text: $markdown)
            .frame(minHeight: 240)
    }
}
```

### Custom toolbar and appearance

```swift
let configuration = MarkdownEditorConfiguration(enabledActions: [.bold, .italic, .heading(level: 1), .bulletList, .link],
                                                highlightsSyntax: true,
                                                font: .preferredFont(forTextStyle: .body),
                                                syntaxColor: .tertiaryLabel)

MarkdownEditor(text: $markdown, configuration: configuration)
```

### Driving the formatter directly

Every toolbar button goes through `MarkdownFormatter`, which is a pure utility you can use on its own if you have a different UI or need to apply formatting server-side:

```swift
let result = MarkdownFormatter.apply(.bold,
                                     to: "Hello, world!",
                                     in: NSRange(location: 0, length: 5))
// result.text      → "**Hello**, world!"
// result.selection → NSRange(location: 2, length: 5)
```

## Testing

Tests are written with Swift Testing and can be run from Xcode or, from the command line, with an iOS Simulator destination:

```sh
xcodebuild test \
    -scheme MarkdownEditorKit \
    -destination 'platform=iOS Simulator,name=iPhone 16'
```

## License

MIT
