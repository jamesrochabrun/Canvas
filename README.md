# Canvas

Canvas is a macOS Swift package for inspecting live `WKWebView` content and sending element context back to your app.

It provides:

- `InspectableWebView` for rendering web content with built-in DOM inspection
- `ElementInspectState` and `.webInspectorOverlay(...)` for input and context flows
- configurable inspector payload levels with `ElementInspectorDataLevel`
- typed style access with `ElementComputedStyleSnapshot`
- optional parent/children/sibling context for richer source resolution
- `ElementSnapshotCapture` for cropped element screenshots
- `DesignToolbarContent` and `DesignEdit` for inline visual editing

## Requirements

- macOS 14+
- Swift 6.0 tools

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

## Quick Start

```swift
import Canvas
import SwiftUI
import WebKit

struct ContentView: View {
  @State private var inspectState = ElementInspectState()
  @State private var isLoading = false
  @State private var currentURL: URL?
  @State private var selectedElement: ElementInspectorData?
  @State private var webView: WKWebView?

  var body: some View {
    VStack {
      Button("Inspect") {
        inspectState.activate(mode: .input)
      }

      InspectableWebView(
        url: URL(string: "https://example.com")!,
        isFileURL: false,
        inspectorDataLevel: .regular,
        onLoadingChange: { isLoading = $0 },
        onURLChange: { currentURL = $0 },
        onElementSelected: { element in
          selectedElement = element
          inspectState.selectElement(element)
        },
        isInspectModeActive: Binding(
          get: { inspectState.isActive },
          set: { _ in }
        ),
        selectedElementId: inspectState.selectedElement?.id,
        onWebViewReady: { webView = $0 }
      )
      .webInspectorOverlay(state: inspectState) { element, instruction in
        let prompt = ElementInspectorPromptBuilder.buildPrompt(
          element: element,
          instruction: instruction
        )
        print(prompt)
      }
    }
  }
}
```

## Inspect Modes

Canvas supports three interaction modes.

### Input Mode

The user clicks an element, types an instruction, and submits.

```swift
inspectState.activate(mode: .input)

.webInspectorOverlay(state: inspectState) { element, instruction in
  let prompt = ElementInspectorPromptBuilder.buildPrompt(
    element: element,
    instruction: instruction
  )
  sendToAgent(prompt)
}
```

### Context Mode

The user clicks an element and the captured data is sent to the host app immediately.

```swift
inspectState.activate(mode: .context)

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

### Crop Mode

The user drags to select a rectangular region. Elements within the crop are scored by overlap ratio (30% minimum), deduplicated to prefer leaf nodes over ancestors, and sent with the region dimensions. The crop rectangle and input follow page scrolling.

```swift
inspectState.activate(mode: .crop)

.webInspectorOverlay(
  state: inspectState,
  onCropSubmit: { rect, elements, instruction in
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: elements,
      instruction: instruction,
      screenshotPath: savedScreenshotPath
    )
    sendToAgent(prompt)
  }
)
```

When no leaf elements pass the overlap threshold (e.g., cropping empty spacing), Canvas falls back to the tightest ancestor containing the crop rect.

## Inspector Payload Levels

`ElementInspectorDataLevel` controls how much DOM and CSS context Canvas captures.

### `.regular`

The default compact payload:

- core metadata (`tagName`, `cssSelector`, text, bounding rect)
- a small computed-style subset
- no parent/children/sibling neighborhood context

Use this when you want lightweight prompt context or multi-selection capture.

### `.full`

The rich payload:

- expanded computed styles (layout, typography, effects, box model, media, transform)
- parent layout context
- children and sibling summaries
- larger text and HTML capture limits

Use this when you need source mapping, inline design editing, or richer debugging context.

```swift
InspectableWebView(
  url: previewURL,
  isFileURL: false,
  inspectorDataLevel: .full,
  onElementSelected: handleSelection
)
```

## Working With Captured Data

`ElementInspectorData` still exposes the raw `computedStyles` dictionary, but the preferred API is the typed accessors:

```swift
let styles = element.styles

styles.display
styles.position
styles.fontSize
styles.textAlign
styles.borderRadius
styles.padding.top
styles.paddingShorthand
styles.margin.left
styles.marginShorthand
styles.boxShadow
```

The parent container is available as structured context:

```swift
if let parent = element.parentContext {
  print(parent.tagName)
  print(parent.display ?? "block")
  print(parent.justifyContent ?? "unset")
  print(parent.gap ?? "0px")
}
```

## Element Snapshots

Use `onWebViewReady` to keep a `WKWebView` reference, then capture a cropped snapshot of the selected element:

```swift
InspectableWebView(
  url: previewURL,
  isFileURL: false,
  onWebViewReady: { webView = $0 }
)
```

```swift
if let webView {
  let image = try await ElementSnapshotCapture.captureSnapshot(
    of: element,
    in: webView
  )
}
```

You can also capture an arbitrary viewport rect:

```swift
let rect = CGRect(x: 40, y: 80, width: 320, height: 180)
let image = try await ElementSnapshotCapture.captureSnapshot(
  of: rect,
  in: webView
)
```

## Design Toolbar

Canvas exposes a reusable inline design toolbar for quick style edits.

```swift
@State private var toolbarValues: DesignToolbarValues?

func handleSelection(_ element: ElementInspectorData) {
  inspectState.selectElement(element)
  toolbarValues = DesignToolbarValues(element: element)
}
```

```swift
if let element = inspectState.selectedElement,
   let toolbarValues {
  DesignToolbarContent(
    values: toolbarValues,
    element: element,
    onEdit: { edit in
      apply(edit)
    }
  )
}
```

Toolbar edits arrive as strongly typed `DesignEdit` values:

```swift
switch edit.action {
case .updateProperty(.fontSize, let value):
  updateCSS("font-size", to: value)
case .updateTextContent(let text):
  updateText(to: text)
case .fitContent:
  fitElementToContent()
case .deleteElement:
  deleteElement()
}
```

## API Overview

| Type | Description |
|------|-------------|
| `ElementInspectState` | Observable state machine controlling inspect lifecycle |
| `InspectMode` | `.input`, `.context`, or `.crop` |
| `InspectableWebView` | `NSViewRepresentable` wrapping `WKWebView` with inspector support |
| `ElementInspectorDataLevel` | Controls compact vs rich capture |
| `ElementInspectorData` | Immutable snapshot of a selected DOM element |
| `ElementComputedStyleSnapshot` | Typed accessors over `computedStyles` |
| `CSSBoxEdges` | Per-side box-model values with synthesized shorthand |
| `ParentLayoutContext` | Typed layout context derived from the parent element |
| `ElementInspectorPromptBuilder` | Builds structured prompt/context text |
| `ElementSnapshotCapture` | Cropped element screenshot capture |
| `DesignToolbarValues` | Observable toolbar state initialized from element styles |
| `DesignToolbarContent` | Reusable SwiftUI toolbar controls |
| `DesignEdit` | Structured edit events emitted by the toolbar |

## License

MIT
