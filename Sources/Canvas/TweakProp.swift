//
//  TweakProp.swift
//  WebInspector
//
//  Value models for the tweakable-props system: a page declares props via
//  `dc_set_props(...)` and the host renders native controls for them.
//

import Foundation

// MARK: - TweakPropType

/// The control kind a tweakable prop renders as.
public enum TweakPropType: String, Equatable, Sendable, CaseIterable {
  case slider
  case select
  case color
  case toggle
  case text
}

// MARK: - TweakPropValue

/// A scalar prop value as declared in the page's `dc_set_props` call.
public enum TweakPropValue: Equatable, Sendable {
  case number(Double)
  case string(String)
  case boolean(Bool)

  public var doubleValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  public var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var boolValue: Bool? {
    if case .boolean(let value) = self { return value }
    return nil
  }

  /// Representation suitable for `JSONSerialization` payloads sent to the page.
  public var bridgeJSONValue: Any {
    switch self {
    case .number(let value): value
    case .string(let value): value
    case .boolean(let value): value
    }
  }
}

// MARK: - TweakProp

/// A single tweakable prop declared by the page.
public struct TweakProp: Identifiable, Equatable, Sendable {
  public let name: String
  public let label: String
  public let type: TweakPropType
  /// Slider range and step; nil for non-slider props or when omitted.
  public let minimum: Double?
  public let maximum: Double?
  public let step: Double?
  /// Choices for `.select` props.
  public let options: [String]
  /// The current value (starts at the declared default).
  public var value: TweakPropValue
  /// The value declared in the page source.
  public let defaultValue: TweakPropValue

  public var id: String { name }

  public init(
    name: String,
    label: String,
    type: TweakPropType,
    minimum: Double? = nil,
    maximum: Double? = nil,
    step: Double? = nil,
    options: [String] = [],
    value: TweakPropValue,
    defaultValue: TweakPropValue? = nil
  ) {
    self.name = name
    self.label = label
    self.type = type
    self.minimum = minimum
    self.maximum = maximum
    self.step = step
    self.options = options
    self.value = value
    self.defaultValue = defaultValue ?? value
  }
}
