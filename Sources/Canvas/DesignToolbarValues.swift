//
//  DesignToolbarValues.swift
//  Canvas
//
//  Observable state backing the inline design toolbar controls.
//  Initialized from an element's computed styles.
//

import AppKit
import SwiftUI

// MARK: - ElementCategory

/// Classifies a DOM element by its tag name to determine which
/// design controls are relevant.
public enum ElementCategory: Sendable, Equatable {
  /// Text elements: h1-h6, p, span, a, label, li, em, strong, etc.
  case text
  /// Buttons: button, input[type=submit/button]
  case button
  /// Media: img, svg, picture, video, canvas
  case image
  /// Layout containers: div, section, article, nav, header, footer, etc.
  case container

  private static let textTags: Set<String> = [
    "H1", "H2", "H3", "H4", "H5", "H6",
    "P", "SPAN", "A", "LABEL", "LI",
    "EM", "STRONG", "B", "I", "U",
    "SMALL", "SUB", "SUP", "MARK",
    "BLOCKQUOTE", "Q", "CITE", "CODE", "PRE",
    "TD", "TH", "CAPTION", "FIGCAPTION", "DT", "DD",
  ]

  private static let buttonTags: Set<String> = [
    "BUTTON",
  ]

  private static let imageTags: Set<String> = [
    "IMG", "SVG", "PICTURE", "VIDEO", "CANVAS",
  ]

  public init(tagName: String) {
    let upper = tagName.uppercased()
    if Self.textTags.contains(upper) {
      self = .text
    } else if Self.buttonTags.contains(upper) {
      self = .button
    } else if Self.imageTags.contains(upper) {
      self = .image
    } else if upper == "INPUT" {
      // INPUT can be button-like or text-like; default to button
      self = .button
    } else {
      self = .container
    }
  }

  /// Whether this category supports text-related controls (font, bold, italic, etc.)
  public var supportsTextControls: Bool {
    switch self {
    case .text, .button: true
    case .image, .container: false
    }
  }

  /// Whether this category supports a background color control.
  public var supportsBackgroundColor: Bool {
    switch self {
    case .button, .container: true
    case .text, .image: false
    }
  }

  /// Whether this category supports image-specific controls.
  public var supportsImageControls: Bool {
    self == .image
  }

  /// Whether this category supports layout controls (padding, border-radius).
  public var supportsLayoutControls: Bool {
    switch self {
    case .container, .button, .image: true
    case .text: false
    }
  }
}

// MARK: - TextAlignment

/// Text alignment options matching CSS `text-align`.
public enum DesignTextAlignment: String, Sendable, CaseIterable {
  case left
  case center
  case right
  case justify

  public var icon: String {
    switch self {
    case .left: "text.alignleft"
    case .center: "text.aligncenter"
    case .right: "text.alignright"
    case .justify: "text.justify"
    }
  }
}

// MARK: - DesignToolbarValues

/// Observable state for the inline design toolbar controls.
///
/// Initialized from an element's normalized style snapshot.
/// Each property change can be observed by the toolbar to emit `DesignEdit` events.
@Observable @MainActor
public final class DesignToolbarValues {

  // MARK: Text properties

  public var fontFamily: String
  public var fontFamilyOptions: [String]
  public var color: String
  public var fontSize: Int
  public var isBold: Bool
  public var isItalic: Bool
  public var textAlign: DesignTextAlignment

  // MARK: Spacing

  public var letterSpacing: String
  public var lineHeight: String

  // MARK: Background & layout

  public var backgroundColor: String
  public var borderRadius: String
  public var padding: String
  public var margin: String

  // MARK: Image

  public var objectFit: String

  // MARK: Content

  public var textContent: String

  // MARK: Metadata

  public let category: ElementCategory

  // MARK: Color helpers

  /// Parses the current `color` CSS string into an `NSColor`.
  public var nsColor: NSColor {
    get { Self.parseColor(color) }
    set { color = Self.serializeColor(newValue) }
  }

  /// Parses the current `backgroundColor` CSS string into an `NSColor`.
  public var nsBackgroundColor: NSColor {
    get { Self.parseColor(backgroundColor) }
    set { backgroundColor = Self.serializeColor(newValue) }
  }

  // MARK: Init

  public init(element: ElementInspectorData) {
    let styles = element.styles
    self.category = ElementCategory(tagName: element.tagName)
    self.textContent = element.textContent

    let resolvedFontFamily = styles.fontFamily ?? "sans-serif"
    self.fontFamily = resolvedFontFamily
    self.fontFamilyOptions = Self.makeFontFamilyOptions(
      currentFontFamily: resolvedFontFamily,
      availableFontFamilies: element.availableFontFamilies
    )
    self.color = styles.textColor ?? "rgb(0, 0, 0)"
    self.backgroundColor = styles.backgroundColor ?? "transparent"

    let rawSize = styles.fontSize ?? "16px"
    self.fontSize = Self.parsePixelValue(rawSize) ?? 16

    let rawWeight = styles.fontWeight ?? "400"
    self.isBold = Self.isBoldWeight(rawWeight)

    let rawStyle = styles.fontStyle ?? "normal"
    self.isItalic = rawStyle.lowercased() == "italic"

    let rawAlign = styles.textAlign ?? "left"
    self.textAlign = DesignTextAlignment(rawValue: rawAlign.lowercased()) ?? .left

    self.letterSpacing = styles.letterSpacing ?? "normal"
    self.lineHeight = styles.lineHeight ?? "normal"
    self.borderRadius = styles.borderRadius ?? "0px"
    self.padding = styles.paddingShorthand ?? "0px"
    self.margin = styles.marginShorthand ?? "0px"
    self.objectFit = styles.objectFit ?? "cover"
  }

  // MARK: Parsing helpers (delegated to nonisolated CSSParser)

  static func styleValue(
    _ styles: [String: String],
    _ keys: String...
  ) -> String? {
    CSSParser.styleValue(styles, keys)
  }

  static func parsePixelValue(_ value: String) -> Int? {
    CSSParser.parsePixelValue(value)
  }

  static func isBoldWeight(_ value: String) -> Bool {
    CSSParser.isBoldWeight(value)
  }

  static func parseColor(_ css: String) -> NSColor {
    CSSParser.parseColor(css)
  }

  static func serializeColor(_ color: NSColor) -> String {
    CSSParser.serializeColor(color)
  }

  static func makeFontFamilyOptions(
    currentFontFamily: String,
    availableFontFamilies: [String]
  ) -> [String] {
    var options: [String] = []
    var seen = Set<String>()

    func append(_ family: String, skipGeneric: Bool = false) {
      guard let normalized = normalizeFontFamily(family) else { return }
      let key = normalized.lowercased()
      guard !skipGeneric || !Self.genericFontFamilies.contains(key) else { return }
      guard seen.insert(key).inserted else { return }
      options.append(normalized)
    }

    if let selectedFamily = parseFontFamilyList(currentFontFamily).first {
      append(selectedFamily)
    }

    for family in availableFontFamilies {
      append(family, skipGeneric: true)
    }

    for family in fallbackFontFamilies {
      append(family)
    }

    return options
  }

  private static func parseFontFamilyList(_ value: String) -> [String] {
    var families: [String] = []
    var current = ""
    var quote: Character?
    var parenDepth = 0

    func appendCurrent() {
      if let normalized = normalizeFontFamily(current) {
        families.append(normalized)
      }
      current = ""
    }

    for character in value {
      if let activeQuote = quote {
        if character == activeQuote {
          quote = nil
        }
        current.append(character)
        continue
      }

      if character == "\"" || character == "'" {
        quote = character
        current.append(character)
        continue
      }

      if character == "(" {
        parenDepth += 1
        current.append(character)
        continue
      }

      if character == ")", parenDepth > 0 {
        parenDepth -= 1
        current.append(character)
        continue
      }

      if character == ",", parenDepth == 0 {
        appendCurrent()
        continue
      }

      current.append(character)
    }

    appendCurrent()
    return families
  }

  private static func normalizeFontFamily(_ value: String) -> String? {
    var name = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 {
      name.removeFirst()
      name.removeLast()
      name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    } else if name.hasPrefix("'"), name.hasSuffix("'"), name.count >= 2 {
      name.removeFirst()
      name.removeLast()
      name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard !name.isEmpty else { return nil }

    let lowercased = name.lowercased()
    guard !lowercased.hasPrefix("var("),
          lowercased != "inherit",
          lowercased != "initial",
          lowercased != "unset",
          lowercased != "revert",
          lowercased != "revert-layer" else {
      return nil
    }

    return name
  }

  private static let fallbackFontFamilies = [
    "system-ui",
    "sans-serif",
    "serif",
    "monospace",
    "Inter",
    "Helvetica",
    "Arial",
    "Georgia",
    "Times New Roman",
  ]

  private static let genericFontFamilies: Set<String> = [
    "serif",
    "sans-serif",
    "monospace",
    "cursive",
    "fantasy",
    "system-ui",
    "ui-serif",
    "ui-sans-serif",
    "ui-monospace",
    "ui-rounded",
    "emoji",
    "math",
    "fangsong",
  ]
}

// MARK: - CSSParser

/// Nonisolated CSS parsing utilities used by `DesignToolbarValues`.
///
/// Extracted from `@MainActor` context so they can be called freely
/// from tests and non-main-actor code.
public enum CSSParser {

  /// Look up a value trying multiple key names (camelCase, kebab-case, etc.)
  public static func styleValue(
    _ styles: [String: String],
    _ keys: [String]
  ) -> String? {
    for key in keys {
      if let value = styles[key], !value.isEmpty {
        return value
      }
    }
    return nil
  }

  /// Strips "px" and parses to Int.
  public static func parsePixelValue(_ value: String) -> Int? {
    let cleaned = value.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces)
    return Int(Double(cleaned) ?? 0)
  }

  /// Returns `true` if the weight string represents bold (>=600 or "bold").
  public static func isBoldWeight(_ value: String) -> Bool {
    let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
    if lower == "bold" || lower == "bolder" { return true }
    if let numeric = Int(lower) { return numeric >= 600 }
    return false
  }

  /// Parses a CSS color string (rgb/rgba/hex) into NSColor.
  public static func parseColor(_ css: String) -> NSColor {
    let trimmed = css.trimmingCharacters(in: .whitespaces).lowercased()

    // rgb(r, g, b) or rgba(r, g, b, a)
    if trimmed.hasPrefix("rgb") {
      let inner = trimmed
        .replacingOccurrences(of: "rgba(", with: "")
        .replacingOccurrences(of: "rgb(", with: "")
        .replacingOccurrences(of: ")", with: "")
      let components = inner.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      guard components.count >= 3,
            let r = Double(components[0]),
            let g = Double(components[1]),
            let b = Double(components[2]) else {
        return .black
      }
      let a = components.count >= 4 ? (Double(components[3]) ?? 1.0) : 1.0
      return NSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    // #hex
    if trimmed.hasPrefix("#") {
      return NSColor(hex: trimmed) ?? .black
    }

    // transparent
    if trimmed == "transparent" {
      return .clear
    }

    return .black
  }

  /// Serializes an NSColor to CSS rgba() string.
  public static func serializeColor(_ color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB) ?? color
    let r = Int(c.redComponent * 255)
    let g = Int(c.greenComponent * 255)
    let b = Int(c.blueComponent * 255)
    let a = c.alphaComponent
    if a < 1.0 {
      return "rgba(\(r), \(g), \(b), \(String(format: "%.2f", a)))"
    }
    return "rgb(\(r), \(g), \(b))"
  }
}

// MARK: - NSColor+Hex

private extension NSColor {
  convenience init?(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

    let length = hexSanitized.count
    switch length {
    case 3:
      let r = CGFloat((rgb & 0xF00) >> 8) / 15.0
      let g = CGFloat((rgb & 0x0F0) >> 4) / 15.0
      let b = CGFloat(rgb & 0x00F) / 15.0
      self.init(red: r, green: g, blue: b, alpha: 1.0)
    case 6:
      let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
      let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
      let b = CGFloat(rgb & 0x0000FF) / 255.0
      self.init(red: r, green: g, blue: b, alpha: 1.0)
    case 8:
      let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
      let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
      let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
      let a = CGFloat(rgb & 0x000000FF) / 255.0
      self.init(red: r, green: g, blue: b, alpha: a)
    default:
      return nil
    }
  }
}
