# Canvas

A Swift library for inspecting and interacting with web elements in `WKWebView` on macOS. Activate inspect mode, hover to highlight elements, click to capture element data, and send instructions or context to your app.

## Requirements

- macOS 14+
- Swift 6.0+ (Swift tools version)

## Installation

Add Canvas as a dependency in your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/jamesrochabrun/Canvas.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
  name: "YourApp",
  dependencies: [
    .product(name: "Canvas", package: "Canvas")
  ]
)
```

Or in Xcode: **File > Add Package Dependencies** and enter `https://github.com/jamesrochabrun/Canvas.git`.

## Quick Start

```swift
import Canvas
import SwiftUI

struct ContentView: View {

  @State private var inspectState = ElementInspectState()
  @State private var isLoading = false
  @State private var currentURL: URL?

  var body: some View {
    VStack {
      HStack {
        Button("Inspect") {
          inspectState.activate()
        }
      }
      .padding()

      InspectableWebView(
        url: URL(string: "https://example.com")!,
        isFileURL: false,
        isLoading: $isLoading,
        currentURL: $currentURL,
        onElementSelected: { element in
          inspectState.selectElement(element)
        },
        isInspectModeActive: .init(
          get: { inspectState.isActive },
          set: { _ in }
        ),
        selectedElementId: inspectState.selectedElement?.id
      )
      .webInspectorOverlay(state: inspectState) { element, instruction in
        let prompt = ElementInspectorPromptBuilder.buildPrompt(
          element: element,
          instruction: instruction
        )
        // Send prompt to your AI agent, terminal, etc.
        print(prompt)
      }
    }
  }
}
```

## Inspect Modes

Canvas supports two interaction modes.

### Input Mode (default)

The user clicks an element, types an instruction in the floating text editor, and submits. This is the default behavior.

```swift
// Activate input mode
inspectState.activate() // or inspectState.activate(mode: .input)

// Handle submission
.webInspectorOverlay(state: inspectState) { element, instruction in
  let prompt = ElementInspectorPromptBuilder.buildPrompt(
    element: element,
    instruction: instruction
  )
  sendToAgent(prompt)
}
```

### Context Mode

The user clicks an element and its data is sent to the app immediately — no text input required. The inspector stays active so the user can keep clicking elements.

```swift
// Activate context mode
inspectState.activate(mode: .context)

// Handle immediate selection
.webInspectorOverlay(
  state: inspectState,
  onContextSelection: { element in
    let context = ElementInspectorPromptBuilder.buildContextPrompt(
      element: element
    )
    sendToAgent(context)
  }
)
```

## Building Prompts

`ElementInspectorPromptBuilder` produces structured text from captured element data.

**Input mode** — includes the user's instruction:

```swift
let prompt = ElementInspectorPromptBuilder.buildPrompt(
  element: element,
  instruction: "Make this button red"
)
// I'm looking at a web element in the live preview:
//
// **Element**: <button class="btn">Submit</button>
// **CSS Selector**: form > button.btn
// **Computed Styles**:
//   backgroundColor: #007AFF
//   fontSize: 16px
//
// User request: Make this button red
//
// Please modify the source code to make this change.
```

**Context mode** — element context only:

```swift
let context = ElementInspectorPromptBuilder.buildContextPrompt(
  element: element
)
// Selected web element context:
//
// **Element**: <button class="btn">Submit</button>
// **CSS Selector**: form > button.btn
// **Computed Styles**:
//   backgroundColor: #007AFF
//   fontSize: 16px
```

## Element Snapshots

`ElementSnapshotCapture` captures a cropped screenshot of any element's bounding rect from the `WKWebView`. It's a standalone utility — use it to send visual context to an AI model, or to verify a design change looks correct after the AI edits code.

No permissions or plist entries required.

### 1. Get the WKWebView reference

Use the `onWebViewReady` callback on `InspectableWebView`:

```swift
@State private var inspectState = ElementInspectState()
@State private weak var webView: WKWebView?

InspectableWebView(
  url: URL(string: "https://example.com")!,
  isFileURL: false,
  onElementSelected: { element in
    inspectState.selectElement(element)
  },
  isInspectModeActive: .init(
    get: { inspectState.isActive },
    set: { _ in }
  ),
  onWebViewReady: { self.webView = $0 }
)
```

### 2. Capture a snapshot

**Snapshot a specific element:**

```swift
if let webView {
  let image = try await ElementSnapshotCapture.captureSnapshot(
    of: element,
    in: webView
  )
  // image is an NSImage cropped to the element's viewport rect
}
```

**Snapshot an arbitrary viewport rect:**

```swift
let rect = CGRect(x: 50, y: 100, width: 300, height: 200)
let image = try await ElementSnapshotCapture.captureSnapshot(
  of: rect,
  in: webView
)
```

**Snapshot the currently selected element (convenience):**

```swift
let image = try await inspectState.captureSelectedElementSnapshot(
  in: webView
)
```

This uses the live viewport rect (updated on scroll/resize), not the stale rect from click time.

### 3. Send to an AI model

```swift
let prompt = ElementInspectorPromptBuilder.buildPrompt(
  element: element,
  instruction: "Make this button more prominent"
)
let screenshot = try await ElementSnapshotCapture.captureSnapshot(
  of: element,
  in: webView
)

// Send both to a multimodal AI model
let message = [
  .image(screenshot.tiffRepresentation!),
  .text(prompt)
]
```

### Error handling

```swift
do {
  let image = try await ElementSnapshotCapture.captureSnapshot(of: element, in: webView)
} catch SnapshotError.zeroRect {
  // Element has zero width or height
} catch SnapshotError.rectOutOfBounds {
  // Element is entirely offscreen
} catch SnapshotError.snapshotFailed(let message) {
  // WebKit snapshot failed: \(message)
}
```

## API Overview

| Type | Description |
|------|-------------|
| `ElementInspectState` | Observable state machine controlling the inspector lifecycle |
| `InspectMode` | `.input` (type instruction) or `.context` (immediate send) |
| `ElementInspectorData` | Immutable snapshot of a captured DOM element |
| `InspectableWebView` | `NSViewRepresentable` wrapping `WKWebView` with inspector support |
| `ElementInspectorBridge` | JavaScript injection and WebKit message handling |
| `ElementInspectorPromptBuilder` | Constructs structured prompts from element data |
| `ElementSnapshotCapture` | Standalone element screenshot capture (crop to bounding rect) |
| `SnapshotError` | Error cases: `zeroRect`, `rectOutOfBounds`, `snapshotFailed` |
| `.webInspectorOverlay()` | View modifier adding the inspector banner and input overlay |

### ElementInspectorData Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `tagName` | `String` | DOM tag name (e.g., `"BUTTON"`) |
| `elementId` | `String` | DOM `id` attribute |
| `className` | `String` | CSS class string |
| `textContent` | `String` | Visible text content |
| `outerHTML` | `String` | Full outer HTML markup |
| `cssSelector` | `String` | Computed CSS selector path |
| `computedStyles` | `[String: String]` | Comprehensive computed CSS properties (70+) |
| `boundingRect` | `CGRect` | Element position and size |
| `parentTagName` | `String` | Parent element's tag name |
| `parentStyles` | `[String: String]` | Parent's layout-relevant styles (display, flex, grid, etc.) |
| `cssVariables` | `[String: String]` | CSS custom properties used by this element (`"--primary"` → `"rgb(37,99,235)"`) |
| `cssVariableBindings` | `[String: String]` | Maps CSS properties to their `var()` expressions (`"color"` → `"var(--primary)"`) |
| `children` | `ElementRelationships` | Direct children summary (count + up to 10 items with tag, id, class, text) |
| `siblings` | `ElementRelationships` | Sibling elements summary (excludes the selected element itself) |

### Captured Computed Styles

The inspector captures a comprehensive set of CSS properties from `getComputedStyle()`:

| Category | Properties |
|----------|-----------|
| **Typography** | fontFamily, fontSize, fontWeight, fontStyle, fontVariant, textAlign, textDecoration, textTransform, letterSpacing, lineHeight, wordSpacing, whiteSpace, textOverflow, textIndent, textShadow |
| **Box model** | paddingTop/Right/Bottom/Left, marginTop/Right/Bottom/Left |
| **Border** | width, color, style per side + per-corner radius |
| **Layout** | display, position, top/right/bottom/left, zIndex, flex properties, grid properties, gap, overflow |
| **Sizing** | width, height, minWidth, maxWidth, minHeight, maxHeight, boxSizing |
| **Visual** | color, backgroundColor, opacity, backgroundImage/Size/Position/Repeat, boxShadow, outline, filter, backdropFilter, mixBlendMode, clipPath |
| **Transform** | transform, transformOrigin, transition |
| **Media** | objectFit, objectPosition |

### CSS Custom Properties (Design Tokens)

When an element's styles use CSS variables (e.g., `color: var(--primary)`), the inspector captures:

- **`cssVariables`**: Variable name → resolved value (e.g., `"--primary"` → `"rgb(37, 99, 235)"`)
- **`cssVariableBindings`**: CSS property → `var()` expression (e.g., `"color"` → `"var(--primary)"`)

This lets AI models edit design tokens instead of hardcoding values. The prompt builder renders this as:

```
**CSS Variables**:
  color uses var(--primary) = rgb(37, 99, 235)
  background-color uses var(--bg-surface) = rgb(255, 255, 255)
```

### Children & Siblings

When an element is selected, the inspector captures summaries of its direct children and siblings (up to 10 each). Each summary includes the tag name, id, class, and text content. This enables AI models to reason about container-level edits like "add a fourth card," "reorder these items," or "make this one stand out from its siblings."

The prompt builder renders this as:

```
**Children** (3):
  div.card — "Authentic Recipes"
  div.card — "Fresh Ingredients"
  div.card — "Family Atmosphere"
**Siblings** (2):
  header.hero — "Welcome"
  footer — "© 2024"
```

### Parent Context

When an element is selected, the inspector also captures the parent element's layout context (display, flexDirection, flexWrap, justifyContent, alignItems, alignContent, gap, gridTemplateColumns, gridTemplateRows, position, overflow). This helps AI models understand how the element is positioned within its container.

### Design Toolbar

Canvas includes a design toolbar system for direct visual editing:

| Type | Description |
|------|-------------|
| `DesignToolbarValues` | Observable state initialized from an element's computed styles |
| `DesignToolbarContent` | SwiftUI controls for font, color, size, alignment, spacing, etc. |
| `DesignEdit` | Structured edit event (property change, text update, fit content, delete) |
| `PromptToolbarContent` | Text input for AI-powered instruction-based editing |
| `ElementCategory` | Classifies elements (text, button, image, container) to show relevant controls |
| `CSSParser` | Utilities for parsing CSS values, colors, and font weights |

## License

MIT
