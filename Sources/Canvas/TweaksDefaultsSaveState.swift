//
//  TweaksDefaultsSaveState.swift
//  WebInspector
//
//  Presentation state for explicitly saving live tweak values as defaults.
//

/// The state of an explicit "Save as defaults" operation.
public enum TweaksDefaultsSaveState: Equatable, Sendable {
  case idle
  case saving
  case failed(String)

  var isSaving: Bool {
    self == .saving
  }

  var failureMessage: String? {
    guard case .failed(let message) = self else { return nil }
    return message
  }
}
