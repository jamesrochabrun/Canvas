//
//  ElementInspectorDataLevel.swift
//  Canvas
//
//  Controls how much DOM and CSS context the inspector bridge captures.
//

import Foundation

/// Controls how much data the web inspector captures for a selected element.
public enum ElementInspectorDataLevel: String, Sendable, Equatable {
  /// Legacy compact payload: core element metadata, a small style subset, and no DOM neighborhood context.
  case regular
  /// Rich payload: expanded computed styles plus parent, children, and sibling context.
  case full

  var styleKeys: [String] {
    switch self {
    case .regular:
      [
        "color",
        "backgroundColor",
        "fontSize",
        "fontWeight",
        "padding",
        "margin",
        "display",
        "borderRadius",
        "width",
        "height",
      ]
    case .full:
      [
        "color", "backgroundColor", "opacity", "visibility",
        "fontFamily", "fontSize", "fontWeight", "fontStyle", "fontVariant",
        "textAlign", "textDecoration", "textTransform", "letterSpacing",
        "lineHeight", "wordSpacing", "whiteSpace", "textOverflow", "textIndent",
        "textShadow",
        "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
        "boxSizing",
        "display", "position", "top", "right", "bottom", "left", "zIndex",
        "flexDirection", "flexWrap", "justifyContent", "alignItems", "alignSelf",
        "alignContent", "flexGrow", "flexShrink", "flexBasis", "order", "gap",
        "gridTemplateColumns", "gridTemplateRows", "gridColumn", "gridRow",
        "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
        "marginTop", "marginRight", "marginBottom", "marginLeft",
        "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth",
        "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor",
        "borderTopStyle", "borderRightStyle", "borderBottomStyle", "borderLeftStyle",
        "borderTopLeftRadius", "borderTopRightRadius",
        "borderBottomRightRadius", "borderBottomLeftRadius",
        "borderRadius",
        "backgroundImage", "backgroundSize", "backgroundPosition", "backgroundRepeat",
        "boxShadow", "outline", "outlineOffset",
        "overflow", "overflowX", "overflowY",
        "transform", "transformOrigin",
        "transition",
        "cursor", "pointerEvents",
        "objectFit", "objectPosition",
        "filter", "backdropFilter", "mixBlendMode", "clipPath",
        "listStyleType", "verticalAlign",
      ]
    }
  }

  var textCharacterLimit: Int {
    switch self {
    case .regular: 100
    case .full: 5000
    }
  }

  var htmlCharacterLimit: Int {
    switch self {
    case .regular: 500
    case .full: 5000
    }
  }

  var includesExtendedContext: Bool {
    self == .full
  }
}
