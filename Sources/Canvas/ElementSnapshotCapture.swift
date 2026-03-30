//
//  ElementSnapshotCapture.swift
//  Canvas
//
//  Standalone utility for capturing cropped screenshots of web elements
//  from a WKWebView. Independent of the selection flow — can be called
//  anytime to snapshot any element or viewport region.
//

import AppKit
import WebKit

// MARK: - SnapshotError

/// Errors that can occur during element snapshot capture.
public enum SnapshotError: Error, Sendable, Equatable {
  /// The provided rect has zero width or height.
  case zeroRect
  /// The rect is entirely outside the web view's visible bounds.
  case rectOutOfBounds
  /// The underlying `WKWebView.takeSnapshot` call failed.
  case snapshotFailed(String)
}

// MARK: - ElementSnapshotCapture

/// Captures a cropped snapshot of a web element's bounding rect from a `WKWebView`.
///
/// Uses `WKSnapshotConfiguration.rect` to crop directly — WebKit handles
/// Retina scaling internally, and the rect is specified in CSS-pixel
/// viewport coordinates (matching `getBoundingClientRect()`).
public enum ElementSnapshotCapture {

  /// Captures a snapshot of the given viewport rect from the web view.
  ///
  /// The rect should be in CSS-pixel viewport coordinates (as returned
  /// by `getBoundingClientRect()`), matching WKWebView's point-based
  /// coordinate system.
  ///
  /// - Parameters:
  ///   - rect: The viewport rect to capture, in CSS pixels.
  ///   - webView: The WKWebView to snapshot.
  /// - Returns: An `NSImage` cropped to the specified rect.
  @MainActor
  public static func captureSnapshot(
    of rect: CGRect,
    in webView: WKWebView
  ) async throws -> NSImage {
    guard rect.width > 0, rect.height > 0 else {
      throw SnapshotError.zeroRect
    }

    let viewBounds = webView.bounds
    let clampedRect = rect.intersection(viewBounds)
    guard !clampedRect.isNull, clampedRect.width > 0, clampedRect.height > 0 else {
      throw SnapshotError.rectOutOfBounds
    }

    let config = WKSnapshotConfiguration()
    config.rect = clampedRect

    return try await takeSnapshot(of: webView, configuration: config)
  }

  /// Captures a snapshot of the given element's bounding rect.
  ///
  /// - Parameters:
  ///   - element: The inspected element whose bounding rect defines the capture area.
  ///   - webView: The WKWebView to snapshot.
  /// - Returns: An `NSImage` cropped to the element's viewport rect.
  @MainActor
  public static func captureSnapshot(
    of element: ElementInspectorData,
    in webView: WKWebView
  ) async throws -> NSImage {
    try await captureSnapshot(of: element.boundingRect, in: webView)
  }

  // MARK: - Private

  @MainActor
  private static func takeSnapshot(
    of webView: WKWebView,
    configuration: WKSnapshotConfiguration
  ) async throws -> NSImage {
    try await withCheckedThrowingContinuation { continuation in
      webView.takeSnapshot(with: configuration) { image, error in
        if let image {
          continuation.resume(returning: image)
        } else {
          continuation.resume(throwing: SnapshotError.snapshotFailed(
            error?.localizedDescription ?? "Unknown snapshot error"
          ))
        }
      }
    }
  }
}
