//
//  TweaksState.swift
//  WebInspector
//
//  Observable model holding the tweakable props declared by the current page.
//

import Foundation
import Observation

/// Holds the tweakable props declared by the current page.
///
/// The host updates the schema from `dc_set_props` messages, mutates values
/// as controls change, and clears the state when navigation starts (the page
/// re-declares its schema on load).
@Observable
@MainActor
public final class TweaksState {
  public private(set) var props: [TweakProp] = []

  public var hasProps: Bool { !props.isEmpty }
  /// Whether any live value differs from its latest saved default.
  public var hasUnsavedChanges: Bool {
    props.contains { $0.value != $0.defaultValue }
  }

  public init() {}

  /// Replaces the schema with the props declared by the page.
  public func updateSchema(_ newProps: [TweakProp]) {
    props = newProps
  }

  /// Updates the local value of a prop so controls stay in sync.
  public func updateValue(name: String, _ value: TweakPropValue) {
    guard let index = props.firstIndex(where: { $0.name == name }) else { return }
    props[index].value = value
  }

  /// Restores all changed props to their latest saved defaults.
  ///
  /// Returns the changed props so the host can apply their restored values
  /// to the live preview without reloading it.
  @discardableResult
  public func resetToDefaults() -> [TweakProp] {
    var resetProps: [TweakProp] = []
    for index in props.indices where props[index].value != props[index].defaultValue {
      props[index].value = props[index].defaultValue
      resetProps.append(props[index])
    }
    return resetProps
  }

  /// Promotes every current live value to the saved-default baseline.
  public func commitCurrentValuesAsDefaults() {
    props = props.map { prop in
      TweakProp(
        name: prop.name,
        label: prop.label,
        type: prop.type,
        minimum: prop.minimum,
        maximum: prop.maximum,
        step: prop.step,
        options: prop.options,
        value: prop.value,
        defaultValue: prop.value
      )
    }
  }

  /// Clears the schema; call when the web view starts a new navigation.
  public func clear() {
    props = []
  }
}
