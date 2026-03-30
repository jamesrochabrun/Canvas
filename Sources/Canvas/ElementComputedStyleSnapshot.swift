//
//  ElementComputedStyleSnapshot.swift
//  Canvas
//
//  Typed accessors over the raw computed style capture emitted by the inspector bridge.
//

import Foundation

/// Per-edge CSS box-model values.
public struct CSSBoxEdges: Equatable, Sendable {
  public let top: String?
  public let right: String?
  public let bottom: String?
  public let left: String?

  public init(
    top: String? = nil,
    right: String? = nil,
    bottom: String? = nil,
    left: String? = nil
  ) {
    self.top = top
    self.right = right
    self.bottom = bottom
    self.left = left
  }

  /// Returns the shortest CSS shorthand representation when all four edges are present.
  public var shorthand: String? {
    guard let top,
          let right,
          let bottom,
          let left else {
      return nil
    }

    if top == right, right == bottom, bottom == left {
      return top
    }
    if top == bottom, right == left {
      return "\(top) \(right)"
    }
    if right == left {
      return "\(top) \(right) \(bottom)"
    }
    return "\(top) \(right) \(bottom) \(left)"
  }

  public var isEmpty: Bool {
    [top, right, bottom, left].allSatisfy { value in
      value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
  }
}

/// Parent container layout context captured alongside the selected element.
public struct ParentLayoutContext: Equatable, Sendable {
  public let tagName: String
  public let rawStyles: [String: String]

  public init(
    tagName: String,
    rawStyles: [String: String]
  ) {
    self.tagName = tagName
    self.rawStyles = rawStyles
  }

  public var display: String? { Self.value(in: rawStyles, keys: ["display"]) }
  public var position: String? { Self.value(in: rawStyles, keys: ["position"]) }
  public var flexDirection: String? { Self.value(in: rawStyles, keys: ["flexDirection", "flex-direction"]) }
  public var justifyContent: String? { Self.value(in: rawStyles, keys: ["justifyContent", "justify-content"]) }
  public var alignItems: String? { Self.value(in: rawStyles, keys: ["alignItems", "align-items"]) }
  public var alignContent: String? { Self.value(in: rawStyles, keys: ["alignContent", "align-content"]) }
  public var flexWrap: String? { Self.value(in: rawStyles, keys: ["flexWrap", "flex-wrap"]) }
  public var gap: String? { Self.value(in: rawStyles, keys: ["gap"]) }
  public var gridTemplateColumns: String? { Self.value(in: rawStyles, keys: ["gridTemplateColumns", "grid-template-columns"]) }
  public var gridTemplateRows: String? { Self.value(in: rawStyles, keys: ["gridTemplateRows", "grid-template-rows"]) }
  public var overflow: String? { Self.value(in: rawStyles, keys: ["overflow"]) }

  public var isEmpty: Bool {
    tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rawStyles.isEmpty
  }

  private static func value(in styles: [String: String], keys: [String]) -> String? {
    ElementComputedStyleSnapshot.value(in: styles, keys: keys)
  }
}

/// Typed style accessors derived from the raw `getComputedStyle()` capture.
public struct ElementComputedStyleSnapshot: Equatable, Sendable {
  public let rawStyles: [String: String]

  public init(rawStyles: [String: String]) {
    self.rawStyles = rawStyles
  }

  public var textColor: String? { Self.value(in: rawStyles, keys: ["color"]) }
  public var backgroundColor: String? { Self.value(in: rawStyles, keys: ["backgroundColor", "background-color"]) }
  public var opacity: String? { Self.value(in: rawStyles, keys: ["opacity"]) }

  public var fontFamily: String? { Self.value(in: rawStyles, keys: ["fontFamily", "font-family"]) }
  public var fontSize: String? { Self.value(in: rawStyles, keys: ["fontSize", "font-size"]) }
  public var fontWeight: String? { Self.value(in: rawStyles, keys: ["fontWeight", "font-weight"]) }
  public var fontStyle: String? { Self.value(in: rawStyles, keys: ["fontStyle", "font-style"]) }
  public var lineHeight: String? { Self.value(in: rawStyles, keys: ["lineHeight", "line-height"]) }
  public var letterSpacing: String? { Self.value(in: rawStyles, keys: ["letterSpacing", "letter-spacing"]) }
  public var textAlign: String? { Self.value(in: rawStyles, keys: ["textAlign", "text-align"]) }
  public var textDecoration: String? { Self.value(in: rawStyles, keys: ["textDecoration", "text-decoration"]) }
  public var textTransform: String? { Self.value(in: rawStyles, keys: ["textTransform", "text-transform"]) }

  public var display: String? { Self.value(in: rawStyles, keys: ["display"]) }
  public var position: String? { Self.value(in: rawStyles, keys: ["position"]) }
  public var width: String? { Self.value(in: rawStyles, keys: ["width"]) }
  public var height: String? { Self.value(in: rawStyles, keys: ["height"]) }
  public var top: String? { Self.value(in: rawStyles, keys: ["top"]) }
  public var right: String? { Self.value(in: rawStyles, keys: ["right"]) }
  public var bottom: String? { Self.value(in: rawStyles, keys: ["bottom"]) }
  public var left: String? { Self.value(in: rawStyles, keys: ["left"]) }

  public var flexDirection: String? { Self.value(in: rawStyles, keys: ["flexDirection", "flex-direction"]) }
  public var justifyContent: String? { Self.value(in: rawStyles, keys: ["justifyContent", "justify-content"]) }
  public var alignItems: String? { Self.value(in: rawStyles, keys: ["alignItems", "align-items"]) }
  public var gap: String? { Self.value(in: rawStyles, keys: ["gap"]) }

  public var borderRadius: String? { Self.value(in: rawStyles, keys: ["borderRadius", "border-radius"]) }
  public var boxShadow: String? { Self.value(in: rawStyles, keys: ["boxShadow", "box-shadow"]) }
  public var objectFit: String? { Self.value(in: rawStyles, keys: ["objectFit", "object-fit"]) }

  public var padding: CSSBoxEdges {
    CSSBoxEdges(
      top: Self.value(in: rawStyles, keys: ["paddingTop", "padding-top"]),
      right: Self.value(in: rawStyles, keys: ["paddingRight", "padding-right"]),
      bottom: Self.value(in: rawStyles, keys: ["paddingBottom", "padding-bottom"]),
      left: Self.value(in: rawStyles, keys: ["paddingLeft", "padding-left"])
    )
  }

  public var margin: CSSBoxEdges {
    CSSBoxEdges(
      top: Self.value(in: rawStyles, keys: ["marginTop", "margin-top"]),
      right: Self.value(in: rawStyles, keys: ["marginRight", "margin-right"]),
      bottom: Self.value(in: rawStyles, keys: ["marginBottom", "margin-bottom"]),
      left: Self.value(in: rawStyles, keys: ["marginLeft", "margin-left"])
    )
  }

  public var paddingShorthand: String? {
    Self.value(in: rawStyles, keys: ["padding"]) ?? padding.shorthand
  }

  public var marginShorthand: String? {
    Self.value(in: rawStyles, keys: ["margin"]) ?? margin.shorthand
  }

  static func value(in styles: [String: String], keys: [String]) -> String? {
    for key in keys {
      if let value = styles[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
        return value
      }
    }
    return nil
  }
}
