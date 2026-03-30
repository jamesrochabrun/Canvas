# Canvas — Project Guide

## Build & Test

```bash
swift build        # Build the library
swift test         # Run all tests (Swift Testing framework)
swift test --filter ElementInspectStateTests   # Run a specific test suite
```

- **Platform**: macOS 14+
- **Swift tools version**: 6.0
- **Swift language mode**: 5

## Architecture

Canvas is a macOS Swift package for web element inspection in WKWebView.

```
Sources/Canvas/
  ElementInspectState.swift           — @Observable state machine (InspectMode, lifecycle)
  ElementInspectorDataLevel.swift     — Capture level selection (regular vs full)
  ElementInspectorData.swift          — Immutable Sendable struct for captured DOM data
  ElementComputedStyleSnapshot.swift  — Typed style and parent-context accessors
  ElementInspectorBridge.swift        — JS injection, WKScriptMessageHandler, parsing
  InspectableWebView.swift            — NSViewRepresentable wrapping WKWebView
  WebInspectInputView.swift           — Floating text-input overlay (input mode)
  WebInspectContextView.swift         — Read-only element summary (context mode)
  WebInspectorOverlay.swift           — ViewModifier combining banner + overlays
  ElementInspectorPromptBuilder.swift — Structured prompt construction
  DesignEdit.swift                    — Structured design edit events
  DesignToolbarValues.swift           — @Observable state for design toolbar controls
  DesignToolbarContent.swift          — Inline design controls (font, color, spacing, etc.)
  PromptToolbarContent.swift          — Text input for AI instruction-based editing
  ElementSnapshotCapture.swift        — Standalone element screenshot capture utility
```

**Key patterns**:
- Enums as namespaces for static functions (`ElementInspectorBridge`, `ElementInspectorPromptBuilder`)
- Value types for data (`ElementInspectorData`), reference types for state (`ElementInspectState`)
- `WeakScriptMessageHandler` proxy to avoid WKWebView retain cycles
- Coordinator pattern for `NSViewRepresentable` lifecycle

## Inspector Capture Levels

Canvas supports two capture levels via `ElementInspectorDataLevel`:

- `regular`: compact payload for lightweight selection/context flows
- `full`: expanded computed styles plus parent, children, and sibling context

`InspectableWebView` defaults to `.regular`:

```swift
InspectableWebView(
  url: previewURL,
  isFileURL: false,
  inspectorDataLevel: .regular,
  onElementSelected: handleSelection
)
```

Use `.full` only when the host app actually needs richer source resolution or inline design tooling.

## Normalized Style Access

Prefer the typed accessors on `ElementInspectorData` over ad hoc raw dictionary reads:

```swift
let styles = element.styles
styles.padding.top
styles.paddingShorthand
styles.margin.left
styles.display
styles.textAlign
styles.boxShadow
```

For parent layout context:

```swift
let parent = element.parentContext
parent?.display
parent?.justifyContent
parent?.gap
```

The raw `computedStyles` dictionary is still available as an escape hatch, but new app-facing code should be built on the typed models.

## Code Style

- **2-space indentation**, spaces only (no tabs)
- K&R brace style (opening brace on same line)
- `// MARK: - Section` to organize code within files
- `///` doc comments on public API
- File headers: `// FileName.swift // WebInspector // Description`

### Naming

- Types: `PascalCase`
- Functions, variables: `camelCase`
- Booleans: `is`/`has` prefix (`isActive`, `isInputShowing`)

### Access control

- `public` on all API-facing types and methods
- Default `internal` for helpers
- `private` for view subcomponents and state

### SwiftUI

- `@Observable` (not `ObservableObject`)
- `@Bindable` to bind `@Observable` properties
- `@State` / `@FocusState` for local view state
- Custom `ViewModifier` structs exposed via `View` extensions

### Concurrency

- `@MainActor` on observable state classes
- `Sendable` on structs/enums crossing isolation boundaries
- `Task { @MainActor in }` for UI updates from callbacks

## Testing

Uses **Swift Testing** (not XCTest):

```swift
@Suite("SuiteName")
struct SomeTests {
  @Test func descriptiveName() {
    #expect(value == expected)
  }
}
```

- `@MainActor` on suites that test state classes
- Shared fixtures in `TestFixtures` enum (`makeButton()`, `makeMinimalDiv()`)
- One test file per source type
- `// MARK: -` sections to group related tests

## Two Inspector Modes

- **Input mode** (`.input`): select element → type instruction → submit via `onSubmit`
- **Context mode** (`.context`): select element → data sent immediately via `onContextSelection` → auto-dismiss

## Documentation

If you change public inspector payloads, normalized style models, or the toolbar API, update:

- `README.md`
- `AGENTS.md`
- `CLAUDE.md`
