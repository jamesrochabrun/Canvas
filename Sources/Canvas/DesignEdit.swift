//
//  DesignEdit.swift
//  Canvas
//
//  Structured design edit event emitted by the design toolbar.
//  The host app receives these to apply CSS or DOM changes.
//

import Foundation

/// A structured design edit produced by the inline design toolbar.
///
/// Each edit carries the target element and the action to apply.
/// The host app maps these to CSS writes, DOM mutations, or agent prompts.
public struct DesignEdit: Sendable, Equatable {

  /// CSS property (or DOM attribute) that can be edited from the toolbar.
  public enum Property: String, Sendable, CaseIterable {
    case fontFamily = "font-family"
    case color = "color"
    case backgroundColor = "background-color"
    case fontSize = "font-size"
    case fontWeight = "font-weight"
    case fontStyle = "font-style"
    case textAlign = "text-align"
    case letterSpacing = "letter-spacing"
    case lineHeight = "line-height"
    case borderRadius = "border-radius"
    case padding = "padding"
    case margin = "margin"
    case objectFit = "object-fit"
  }

  /// The kind of edit the user performed.
  public enum Action: Sendable, Equatable {
    /// Update a CSS property to a new value.
    case updateProperty(Property, value: String)
    /// Replace the element's visible text content.
    case updateTextContent(String)
    /// Fit the element to its content (auto-size).
    case fitContent
    /// Delete the element from the DOM.
    case deleteElement
  }

  /// The element being edited.
  public let element: ElementInspectorData
  /// The edit action to apply.
  public let action: Action

  public init(element: ElementInspectorData, action: Action) {
    self.element = element
    self.action = action
  }
}
