//
//  ElementInspectorData.swift
//  WebInspector
//
//  Data captured when a user clicks an element in inspect mode.
//

import CoreGraphics
import Foundation

/// DOM element data captured by the JS inspector bridge.
public struct ElementInspectorData: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let tagName: String
  /// DOM `id` attribute (may be empty)
  public let elementId: String
  /// `class` attribute string (may be empty)
  public let className: String
  /// Visible text content
  public let textContent: String
  /// Outer HTML markup
  public let outerHTML: String
  /// Unique CSS selector path, e.g. `.form > button.primary`
  public let cssSelector: String
  /// Computed styles captured from `getComputedStyle()`.
  public let computedStyles: [String: String]
  /// Element bounding rect in viewport coordinates (`getBoundingClientRect()`).
  public let boundingRect: CGRect
  /// Parent element tag name (empty when parent is `<body>` or absent).
  public let parentTagName: String
  /// Parent element's layout-relevant computed styles (display, flex, grid, etc.).
  public let parentStyles: [String: String]
  /// CSS custom properties (variables) used by this element (`"--primary"` → `"rgb(37,99,235)"`).
  public let cssVariables: [String: String]
  /// Maps CSS properties to their `var()` expressions (`"color"` → `"var(--primary)"`).
  public let cssVariableBindings: [String: String]

  public init(
    id: UUID = UUID(),
    tagName: String,
    elementId: String,
    className: String,
    textContent: String,
    outerHTML: String,
    cssSelector: String,
    computedStyles: [String: String],
    boundingRect: CGRect,
    parentTagName: String = "",
    parentStyles: [String: String] = [:],
    cssVariables: [String: String] = [:],
    cssVariableBindings: [String: String] = [:]
  ) {
    self.id = id
    self.tagName = tagName
    self.elementId = elementId
    self.className = className
    self.textContent = textContent
    self.outerHTML = outerHTML
    self.cssSelector = cssSelector
    self.computedStyles = computedStyles
    self.boundingRect = boundingRect
    self.parentTagName = parentTagName
    self.parentStyles = parentStyles
    self.cssVariables = cssVariables
    self.cssVariableBindings = cssVariableBindings
  }
}
