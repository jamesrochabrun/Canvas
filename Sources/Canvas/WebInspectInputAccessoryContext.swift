//
//  WebInspectInputAccessoryContext.swift
//  WebInspector
//
//  Context handed to the host-provided input accessory shown in the
//  inspect input and crop editors.
//

import CoreGraphics
import Foundation

/// Context passed to the `inputAccessory` view builder of `webInspectorOverlay`.
///
/// Describes the current selection, exposes the instruction typed so far, and
/// lets the host close the editor the same way a submit does.
public struct WebInspectInputAccessoryContext {

  /// What the inspector currently has selected.
  public enum Selection {
    /// A single element selected in input mode.
    case element(ElementInspectorData)
    /// A crop rectangle and the elements captured within it (crop mode).
    case crop(rect: CGRect, elements: [ElementInspectorData])
  }

  /// The current selection: an element in input mode, or a crop rect plus
  /// captured elements in crop mode.
  public let selection: Selection

  /// The instruction typed so far, trimmed of surrounding whitespace.
  /// Empty when nothing has been typed.
  public let draftText: String

  let onDismiss: @MainActor () -> Void

  /// Closes the editor the same way a submit does, honoring the overlay's
  /// `deactivateOnSubmit` setting.
  ///
  /// A control that consumes the selection should call this so the editor
  /// closes and inspect mode ends or stays active exactly as it would after
  /// a Return submit.
  @MainActor
  public func dismiss() {
    onDismiss()
  }
}

// MARK: - Factories

extension WebInspectInputAccessoryContext {

  /// Builds the context for the input-mode editor, or `nil` when no element
  /// is selected.
  @MainActor
  static func forInput(
    state: ElementInspectState,
    draftText: String,
    deactivateOnSubmit: Bool
  ) -> WebInspectInputAccessoryContext? {
    guard let element = state.selectedElement else { return nil }
    return WebInspectInputAccessoryContext(
      selection: .element(element),
      draftText: draftText.trimmingCharacters(in: .whitespacesAndNewlines),
      onDismiss: {
        if deactivateOnSubmit {
          state.deactivate()
        } else {
          state.dismissInput()
        }
      }
    )
  }

  /// Builds the context for the crop-mode editor, or `nil` when no crop
  /// rectangle is selected.
  @MainActor
  static func forCrop(
    state: ElementInspectState,
    draftText: String,
    deactivateOnSubmit: Bool
  ) -> WebInspectInputAccessoryContext? {
    guard let cropRect = state.cropRect else { return nil }
    return WebInspectInputAccessoryContext(
      selection: .crop(rect: cropRect, elements: state.cropElements),
      draftText: draftText.trimmingCharacters(in: .whitespacesAndNewlines),
      onDismiss: {
        if deactivateOnSubmit {
          state.deactivate()
        } else {
          state.dismissCropRect()
        }
      }
    )
  }
}
