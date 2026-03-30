//
//  ElementInspectorPromptBuilder.swift
//  WebInspector
//
//  Constructs the structured prompt sent to Claude after the user
//  selects an element and describes their desired change.
//

import Foundation

/// Builds a structured prompt from inspected element data and a user instruction.
public enum ElementInspectorPromptBuilder {
  private static let relevantStyles = [
    "color", "backgroundColor", "opacity",
    "fontFamily", "fontSize", "fontWeight", "fontStyle",
    "textAlign", "textDecoration", "textTransform", "letterSpacing",
    "lineHeight", "whiteSpace", "textShadow",
    "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
    "display", "position", "zIndex",
    "flexDirection", "flexWrap", "justifyContent", "alignItems", "alignSelf", "gap",
    "gridTemplateColumns", "gridTemplateRows",
    "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
    "marginTop", "marginRight", "marginBottom", "marginLeft",
    "borderTopWidth", "borderTopColor", "borderTopStyle",
    "borderRightWidth", "borderRightColor", "borderRightStyle",
    "borderBottomWidth", "borderBottomColor", "borderBottomStyle",
    "borderLeftWidth", "borderLeftColor", "borderLeftStyle",
    "borderTopLeftRadius", "borderTopRightRadius",
    "borderBottomRightRadius", "borderBottomLeftRadius",
    "backgroundImage", "backgroundSize", "backgroundPosition",
    "boxShadow", "overflow",
    "transform", "objectFit", "filter", "backdropFilter",
  ]

  /// Constructs the prompt string sent to the terminal session.
  public static func buildPrompt(
    element: ElementInspectorData,
    instruction: String
  ) -> String {
    var lines = [
      "I'm looking at a web element in the live preview:",
      "",
    ]
    lines.append(contentsOf: elementLines(for: element))

    lines.append("")
    lines.append("User request: \(instruction)")
    lines.append("")
    lines.append("Please modify the source code to make this change.")

    return lines.joined(separator: "\n")
  }

  /// Constructs the prompt string for multiple selected elements.
  public static func buildPrompt(
    elements: [ElementInspectorData],
    instruction: String
  ) -> String {
    guard !elements.isEmpty else { return "" }
    if elements.count == 1, let element = elements.first {
      return buildPrompt(element: element, instruction: instruction)
    }

    var lines = [
      "I'm looking at web elements in the live preview:",
      "",
    ]

    for (index, element) in elements.enumerated() {
      lines.append("### Element \(index + 1)")
      lines.append(contentsOf: elementLines(for: element))
      if index < elements.count - 1 {
        lines.append("")
      }
    }

    lines.append("")
    lines.append("User request: \(instruction)")
    lines.append("")
    lines.append("Please modify the source code to make this change.")

    return lines.joined(separator: "\n")
  }

  /// Constructs a context-only prompt (no user instruction).
  ///
  /// Used in context mode where the element data is sent immediately
  /// without the user typing an instruction.
  public static func buildContextPrompt(
    element: ElementInspectorData
  ) -> String {
    var lines = [
      "Selected web element context:",
      "",
    ]
    lines.append(contentsOf: elementLines(for: element))

    return lines.joined(separator: "\n")
  }

  /// Constructs a context-only prompt for multiple selected elements.
  public static func buildContextPrompt(
    elements: [ElementInspectorData]
  ) -> String {
    guard !elements.isEmpty else { return "" }
    if elements.count == 1, let element = elements.first {
      return buildContextPrompt(element: element)
    }

    var lines = [
      "Selected web element context:",
      "",
    ]

    for (index, element) in elements.enumerated() {
      lines.append("### Element \(index + 1)")
      lines.append(contentsOf: elementLines(for: element))
      if index < elements.count - 1 {
        lines.append("")
      }
    }

    return lines.joined(separator: "\n")
  }

  private static func elementLines(for element: ElementInspectorData) -> [String] {
    var lines = [
      "**Element**: \(element.outerHTML.isEmpty ? element.tagName.lowercased() : element.outerHTML)",
      "**CSS Selector**: \(element.cssSelector)",
    ]

    let presentStyles = relevantStyles.compactMap { key -> String? in
      guard let value = element.computedStyles[key], !value.isEmpty else { return nil }
      return "  \(key): \(value)"
    }
    if !presentStyles.isEmpty {
      lines.append("**Computed Styles**:")
      lines.append(contentsOf: presentStyles)
    }

    if !element.cssVariableBindings.isEmpty {
      let bindingEntries = element.cssVariableBindings.map { property, expression -> String in
        let varName = expression
          .replacingOccurrences(of: "var(", with: "")
          .replacingOccurrences(of: ")", with: "")
          .trimmingCharacters(in: .whitespaces)
        let resolved = element.cssVariables[varName] ?? ""
        return "  \(property) uses \(expression)\(resolved.isEmpty ? "" : " = \(resolved)")"
      }.sorted()
      lines.append("**CSS Variables**:")
      lines.append(contentsOf: bindingEntries)
    }

    if !element.parentTagName.isEmpty {
      let parentStyleEntries = element.parentStyles.compactMap { key, value -> String? in
        guard !value.isEmpty else { return nil }
        return "  \(key): \(value)"
      }.sorted()
      lines.append("**Parent** (\(element.parentTagName.lowercased())):")
      lines.append(contentsOf: parentStyleEntries)
    }

    if element.children.count > 0 {
      lines.append("**Children** (\(element.children.count)):")
      lines.append(contentsOf: element.children.items.map { summarize($0) })
    }

    if element.siblings.count > 0 {
      lines.append("**Siblings** (\(element.siblings.count)):")
      lines.append(contentsOf: element.siblings.items.map { summarize($0) })
    }

    if !element.interactiveStates.isEmpty {
      lines.append("**Interactive States**:")
      for state in element.interactiveStates.keys.sorted() {
        guard let properties = element.interactiveStates[state] else { continue }
        lines.append("  :\(state)")
        for (property, value) in properties.sorted(by: { $0.key < $1.key }) {
          lines.append("    \(property): \(value)")
        }
      }
    }

    return lines
  }

  private static func summarize(_ item: ElementSummary) -> String {
    var parts = [item.tagName.lowercased()]
    if !item.elementId.isEmpty { parts.append("#\(item.elementId)") }
    if !item.className.isEmpty { parts.append(".\(item.className.replacingOccurrences(of: " ", with: "."))") }
    let label = parts.joined()
    if item.textContent.isEmpty { return "  \(label)" }
    return "  \(label) — \"\(item.textContent)\""
  }
}
