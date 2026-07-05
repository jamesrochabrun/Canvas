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

  /// Clears the schema; call when the web view starts a new navigation.
  public func clear() {
    props = []
  }
}
