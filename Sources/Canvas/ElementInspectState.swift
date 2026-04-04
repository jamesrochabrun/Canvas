//
//  ElementInspectState.swift
//  WebInspector
//
//  Observable state for the web element inspector overlay.
//

import SwiftUI
import WebKit

/// The inspector interaction mode.
public enum InspectMode: Sendable, Equatable {
  /// User types an instruction before sending (default).
  case input
  /// Element context is sent immediately on selection.
  case context
  /// User drags to select a rectangular region.
  case crop
}

/// Observable state controlling the web element inspector lifecycle.
///
/// Activate -> hover -> click -> input -> submit/dismiss.
@Observable @MainActor
public final class ElementInspectState {
  /// Whether inspect mode is currently active (highlight-on-hover enabled)
  public var isActive = false

  /// The current inspector interaction mode.
  public var mode: InspectMode = .input

  /// The element the user clicked; non-nil when the input overlay should show
  public var selectedElement: ElementInspectorData?

  /// The selected element's live bounding rect in viewport coordinates.
  public var selectedElementViewportRect: CGRect?

  /// The user-drawn crop rectangle in viewport coordinates.
  public var cropRect: CGRect?

  /// Elements found within the crop rectangle.
  public var cropElements: [ElementInspectorData] = []

  /// Whether the web content is reloading; the overlay reduces opacity to mask position shifts.
  public var isReloading = false

  /// Whether the instruction input overlay is visible
  public var isInputShowing: Bool { selectedElement != nil }

  /// Whether the crop input overlay is visible
  public var isCropInputShowing: Bool { cropRect != nil }

  /// Convenience check for context mode.
  public var isContextMode: Bool { mode == .context }

  /// Convenience check for crop mode.
  public var isCropMode: Bool { mode == .crop }

  public init() {}

  /// Activates inspect mode.
  public func activate(mode: InspectMode = .input) {
    self.mode = mode
    isActive = true
    clearSelection()
  }

  /// Deactivates inspect mode and clears any selected element.
  public func deactivate() {
    isActive = false
    clearSelection()
  }

  /// Records the clicked element and shows the input overlay.
  public func selectElement(_ element: ElementInspectorData) {
    selectedElement = element
    selectedElementViewportRect = element.boundingRect
  }

  /// Records the user-drawn crop rectangle and the elements within it.
  public func selectCropRect(_ rect: CGRect, elements: [ElementInspectorData] = []) {
    cropRect = rect
    cropElements = elements
  }

  /// Updates the selected element's viewport rect without replacing the selection.
  public func updateSelectedElementViewportRect(_ rect: CGRect) {
    guard selectedElement != nil else { return }
    selectedElementViewportRect = rect
  }

  /// Dismisses the input overlay without deactivating inspect mode.
  public func dismissInput() {
    clearSelection()
  }

  /// Dismisses the crop rectangle without deactivating inspect mode.
  public func dismissCropRect() {
    cropRect = nil
    cropElements = []
  }

  /// Captures a snapshot of the currently selected element.
  ///
  /// Uses the live viewport rect (updated on scroll/resize) rather than
  /// the rect from click time, so the crop matches what's on screen now.
  ///
  /// - Parameter webView: The `WKWebView` displaying the content.
  /// - Returns: An `NSImage` cropped to the selected element's viewport rect.
  public func captureSelectedElementSnapshot(
    in webView: WKWebView
  ) async throws -> NSImage {
    guard let rect = selectedElementViewportRect else {
      throw SnapshotError.zeroRect
    }
    return try await ElementSnapshotCapture.captureSnapshot(of: rect, in: webView)
  }

  /// Captures a snapshot of the user-drawn crop rectangle.
  ///
  /// - Parameter webView: The `WKWebView` displaying the content.
  /// - Returns: An `NSImage` cropped to the crop rect.
  public func captureCropSnapshot(
    in webView: WKWebView
  ) async throws -> NSImage {
    guard let rect = cropRect else {
      throw SnapshotError.zeroRect
    }
    return try await ElementSnapshotCapture.captureSnapshot(of: rect, in: webView)
  }

  private func clearSelection() {
    selectedElement = nil
    selectedElementViewportRect = nil
    cropRect = nil
    cropElements = []
  }
}
