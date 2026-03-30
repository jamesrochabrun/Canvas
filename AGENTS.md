# Canvas — Agent Guidelines

Instructions for AI coding agents (Claude Code, Codex, Copilot, etc.) working on this project.

## Before You Start

1. Read `CLAUDE.md` for build commands, architecture, and code style.
2. Run `swift build` to verify the project compiles before making changes.
3. Run `swift test` after every change to catch regressions.

## Making Changes

### Adding a new source file

1. Place it in `Sources/Canvas/`.
2. Follow the file header convention:
   ```swift
   //
   //  FileName.swift
   //  WebInspector
   //
   //  Brief description of what this file does.
   //
   ```
3. Use `// MARK: -` sections to organize code.
4. Mark public API with `public`. Keep internal helpers `internal` or `private`.

### Adding a new test file

1. Place it in `Tests/CanvasTests/`.
2. Use Swift Testing (`@Suite`, `@Test`, `#expect`) — not XCTest.
3. Import with `@testable import Canvas`.
4. Add `@MainActor` to suites that test `@MainActor` types.
5. Use `TestFixtures` for reusable element data (see `CanvasTests.swift`).

### Modifying the inspector pipeline

The data flow is:

```
JS click → WKScriptMessageHandler → ElementInspectorBridge.parseElementData()
  → ElementInspectState.selectElement() → WebInspectorOverlay shows UI
  → onSubmit / onContextSelection callback → ElementInspectorPromptBuilder
```

- **State changes** go in `ElementInspectState`.
- **JS behavior** goes in `ElementInspectorBridge` (the JS string in `userScript`).
- **Parsing** goes in `ElementInspectorBridge.parseElementData()`.
- **UI** goes in `WebInspectInputView`, `WebInspectContextView`, or `WebInspectorOverlay`.
- **Prompt formatting** goes in `ElementInspectorPromptBuilder`.
- **Design toolbar state** goes in `DesignToolbarValues` (observable, initialized from element data).
- **Design toolbar UI** goes in `DesignToolbarContent` (inline controls for font, color, spacing, etc.).
- **Design edit events** go in `DesignEdit` (structured actions emitted by the toolbar).
- **Prompt input UI** goes in `PromptToolbarContent` (text input for AI instructions).
- **CSS parsing utilities** go in `CSSParser` (inside `DesignToolbarValues.swift`).
- **Element screenshots** go in `ElementSnapshotCapture` (standalone utility, not coupled to selection flow).

### Captured element data

`ElementInspectorData` captures 70+ computed CSS properties from the DOM element plus parent layout context:

- **Typography**: fontFamily, fontSize, fontWeight, fontStyle, textAlign, textDecoration, textTransform, letterSpacing, lineHeight, etc.
- **Box model**: paddingTop/Right/Bottom/Left, marginTop/Right/Bottom/Left (individual sides)
- **Border**: width, color, style per side + per-corner radius
- **Layout**: display, position, flex/grid properties, gap, overflow, zIndex
- **Sizing**: width, height, min/max variants, boxSizing
- **Visual**: color, backgroundColor, opacity, backgroundImage, boxShadow, filter, backdropFilter, transform, etc.
- **Media**: objectFit, objectPosition
- **Parent context**: parentTagName + parent's display, flex, grid, gap, position, overflow
- **CSS variables**: `cssVariables` (variable name → resolved value), `cssVariableBindings` (property → var expression). Extracted by walking `document.styleSheets` for matching rules that use `var()`.
- **Children/siblings**: `children` and `siblings` (`ElementRelationships` with count + up to 10 `ElementSummary` items). Each item has tagName, elementId, className, textContent (truncated to 50 chars).
- **Interactive states**: `interactiveStates` maps pseudo-class name (e.g. `"hover"`, `"focus"`) to a dictionary of CSS properties and values. Extracted by walking `document.styleSheets` for rules with pseudo-class selectors matching the element.

The highlight overlay shows a tag-name label (e.g., "h1", "div") at the top-right corner of the selection box.

### Element snapshots

`ElementSnapshotCapture` provides standalone screenshot capture, independent of the selection flow:

```swift
// Snapshot an element's bounding rect
let image = try await ElementSnapshotCapture.captureSnapshot(of: element, in: webView)

// Snapshot an arbitrary viewport rect
let image = try await ElementSnapshotCapture.captureSnapshot(of: rect, in: webView)

// Convenience: snapshot the currently selected element via state
let image = try await inspectState.captureSelectedElementSnapshot(in: webView)
```

To obtain the `WKWebView` reference, use the `onWebViewReady` callback on `InspectableWebView`:

```swift
InspectableWebView(url: myURL, isFileURL: false, onWebViewReady: { self.webView = $0 }, ...)
```

Errors: `SnapshotError.zeroRect`, `.rectOutOfBounds`, `.snapshotFailed(String)`.

### Style rules

- 2-space indentation, no tabs.
- `@Observable` for state — never `ObservableObject`.
- `@MainActor` on state classes. `Sendable` on data types.
- Prefer value types (structs/enums) over classes unless observable state is needed.
- Use `///` doc comments on public API. Skip comments on obvious code.
- No force unwraps in production code. Use `guard`/`if let` or nil coalescing.

## Do Not

- Add external dependencies without discussion. This package has zero dependencies.
- Use XCTest. The project uses Swift Testing exclusively.
- Add `Co-Authored-By` lines to commits.
- Create documentation files (README updates, etc.) unless explicitly asked.
- Over-engineer: no abstractions for one-time operations, no speculative features.

## Verification Checklist

Before considering a task complete:

- [ ] `swift build` succeeds
- [ ] `swift test` passes (all 84+ tests)
- [ ] New public API has `///` doc comments
- [ ] New logic has corresponding tests
- [ ] No compiler warnings introduced
