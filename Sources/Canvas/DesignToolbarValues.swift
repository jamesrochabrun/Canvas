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
/// Initialized from an element's `computedStyles` dictionary.
/// Each property change can be observed by the toolbar to emit `DesignEdit` events.
@Observable @MainActor
public final class DesignToolbarValues {

  // MARK: Text properties

  public var fontFamily: String
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
    let styles = element.computedStyles
    self.category = ElementCategory(tagName: element.tagName)
    self.textContent = element.textContent

    self.fontFamily = Self.styleValue(styles, "fontFamily", "font-family") ?? "sans-serif"
    self.color = Self.styleValue(styles, "color") ?? "rgb(0, 0, 0)"
    self.backgroundColor = Self.styleValue(styles, "backgroundColor", "background-color") ?? "transparent"

    let rawSize = Self.styleValue(styles, "fontSize", "font-size") ?? "16px"
    self.fontSize = Self.parsePixelValue(rawSize) ?? 16

    let rawWeight = Self.styleValue(styles, "fontWeight", "font-weight") ?? "400"
    self.isBold = Self.isBoldWeight(rawWeight)

    let rawStyle = Self.styleValue(styles, "fontStyle", "font-style") ?? "normal"
    self.isItalic = rawStyle.lowercased() == "italic"

    let rawAlign = Self.styleValue(styles, "textAlign", "text-align") ?? "left"
    self.textAlign = DesignTextAlignment(rawValue: rawAlign.lowercased()) ?? .left

    self.letterSpacing = Self.styleValue(styles, "letterSpacing", "letter-spacing") ?? "normal"
    self.lineHeight = Self.styleValue(styles, "lineHeight", "line-height") ?? "normal"
    self.borderRadius = Self.styleValue(styles, "borderRadius", "border-radius") ?? "0px"
    self.padding = Self.styleValue(styles, "padding") ?? "0px"
    self.margin = Self.styleValue(styles, "margin") ?? "0px"
    self.objectFit = Self.styleValue(styles, "objectFit", "object-fit") ?? "cover"
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
