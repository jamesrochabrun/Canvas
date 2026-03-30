//
//  ElementInspectorData.swift
//  WebInspector
//
//  Data captured when a user clicks an element in inspect mode.
//

import CoreGraphics
import Foundation

/// Summary of a child or sibling element.
public struct ElementSummary: Equatable, Sendable {
  public let tagName: String
  public let elementId: String
  public let className: String
  public let textContent: String

  public init(
    tagName: String,
    elementId: String = "",
    className: String = "",
    textContent: String = ""
  ) {
    self.tagName = tagName
    self.elementId = elementId
    self.className = className
    self.textContent = textContent
  }
}

/// Summary of an element's children or siblings.
public struct ElementRelationships: Equatable, Sendable {
  /// Total count (may exceed `items.count` when capped at 10).
  public let count: Int
  /// Up to 10 summarized elements.
  public let items: [ElementSummary]

  public init(count: Int = 0, items: [ElementSummary] = []) {
    self.count = count
    self.items = items
  }
}

/// DOM element data captured by the JS inspector bridge.
public struct ElementInspectorData: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let tagName: String
  /// DOM `id` attribute (may be empty)
  public let elementId: String
  /// `class` attribute string (may be empty)
  public let className: String
  /// Visible text content (capped at 5,000 chars)
  public let textContent: String
  /// Outer HTML markup (capped at 5,000 chars)
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
  /// Direct children summary (tag, id, class, text for up to 10 children).
  public let children: ElementRelationships
  /// Sibling elements summary (excludes the selected element itself).
  public let siblings: ElementRelationships

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
    children: ElementRelationships = ElementRelationships(),
    siblings: ElementRelationships = ElementRelationships()
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
    self.children = children
    self.siblings = siblings
  }
}
