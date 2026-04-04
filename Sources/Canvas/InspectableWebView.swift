//
//  InspectableWebView.swift
//  WebInspector
//
//  Reusable NSViewRepresentable wrapping WKWebView with built-in
//  element inspector support. Supports both localhost and file URLs.
//

import SwiftUI
import WebKit

// MARK: - InspectableWebView

/// Wraps a `WKWebView` for rendering web content with built-in element inspector support.
///
/// For file URLs, uses `loadFileURL(_:allowingReadAccessTo:)` so relative assets (CSS, JS, images)
/// resolve correctly within the project directory.
///
/// The inspector overlay (hover highlight, click capture) is injected automatically.
/// Control it via `isInspectModeActive` and receive click data via `onElementSelected`.
public struct InspectableWebView: NSViewRepresentable {
  public let url: URL
  public let isFileURL: Bool
  public let inspectorDataLevel: ElementInspectorDataLevel
  /// Directory to grant read access for file URLs (typically the project root)
  public let allowingReadAccessTo: URL?
  public var onLoadingChange: ((Bool) -> Void)?
  public var onURLChange: ((URL?) -> Void)?
  public let onError: ((String) -> Void)?
  /// Change this token to force a reload (useful for file:// URLs that don't change path)
  public var reloadToken: UUID? = nil
  /// Called when the user clicks an element in inspect mode
  public var onElementSelected: ((ElementInspectorData) -> Void)?
  /// Called when the selected element's viewport rect changes due to scrolling or resizing.
  public var onSelectedElementViewportRectChange: ((CGRect) -> Void)?
  /// Called when the user finishes dragging a crop rectangle, with the elements found within it.
  public var onCropRectSelected: ((CGRect, [ElementInspectorData]) -> Void)?
  /// Called when the crop rectangle's viewport position changes due to scrolling or resizing.
  public var onCropRectViewportChange: ((CGRect) -> Void)?
  /// Binding controlling whether the JS inspector overlay is active
  public var isInspectModeActive: Binding<Bool>?
  /// The current inspect mode, used to choose between element and crop activation in JS.
  public var inspectMode: InspectMode = .input
  /// ID of the currently selected element; nil means no selection (clears JS lock)
  public var selectedElementId: UUID? = nil
  /// CSS selector to scroll to and re-select after a reload completes.
  public var selectorToRestore: String? = nil
  /// Called once when the underlying `WKWebView` is created.
  /// Store a weak reference to use with `ElementSnapshotCapture`.
  public var onWebViewReady: ((WKWebView) -> Void)?

  public init(
    url: URL,
    isFileURL: Bool,
    inspectorDataLevel: ElementInspectorDataLevel = .regular,
    allowingReadAccessTo: URL? = nil,
    onLoadingChange: ((Bool) -> Void)? = nil,
    onURLChange: ((URL?) -> Void)? = nil,
    onError: ((String) -> Void)? = nil,
    reloadToken: UUID? = nil,
    onElementSelected: ((ElementInspectorData) -> Void)? = nil,
    onSelectedElementViewportRectChange: ((CGRect) -> Void)? = nil,
    onCropRectSelected: ((CGRect, [ElementInspectorData]) -> Void)? = nil,
    onCropRectViewportChange: ((CGRect) -> Void)? = nil,
    isInspectModeActive: Binding<Bool>? = nil,
    inspectMode: InspectMode = .input,
    selectedElementId: UUID? = nil,
    selectorToRestore: String? = nil,
    onWebViewReady: ((WKWebView) -> Void)? = nil
  ) {
    self.url = url
    self.isFileURL = isFileURL
    self.inspectorDataLevel = inspectorDataLevel
    self.allowingReadAccessTo = allowingReadAccessTo
    self.onLoadingChange = onLoadingChange
    self.onURLChange = onURLChange
    self.onError = onError
    self.reloadToken = reloadToken
    self.onElementSelected = onElementSelected
    self.onSelectedElementViewportRectChange = onSelectedElementViewportRectChange
    self.onCropRectSelected = onCropRectSelected
    self.onCropRectViewportChange = onCropRectViewportChange
    self.isInspectModeActive = isInspectModeActive
    self.inspectMode = inspectMode
    self.selectedElementId = selectedElementId
    self.selectorToRestore = selectorToRestore
    self.onWebViewReady = onWebViewReady
  }

  public func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    #if DEBUG
    configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
    #endif

    // Element inspector — highlight on hover, capture element data on click
    configuration.userContentController.addUserScript(
      ElementInspectorBridge.makeUserScript(for: inspectorDataLevel)
    )
    ElementInspectorBridge.registerMessageHandler(
      on: configuration.userContentController,
      delegate: context.coordinator
    )

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.allowsMagnification = true
    webView.allowsBackForwardNavigationGestures = true

    context.coordinator.webView = webView
    onWebViewReady?(webView)
    loadContent(in: webView)
    return webView
  }

  public func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self

    let urlChanged = context.coordinator.lastLoadedURL != url
    let tokenChanged = context.coordinator.lastReloadToken != reloadToken

    if urlChanged {
      loadContent(in: webView)
      context.coordinator.lastReloadToken = reloadToken
    } else if tokenChanged {
      webView.reload()
      context.coordinator.lastReloadToken = reloadToken
    }

    // Sync inspect mode with JS without triggering redundant evaluations
    let newInspectState = isInspectModeActive?.wrappedValue ?? false
    let newMode = inspectMode
    let oldMode = context.coordinator.lastInspectMode
    let modeChanged = newMode != oldMode

    if newInspectState != context.coordinator.lastInspectModeState || (modeChanged && newInspectState) {
      // Deactivate the old mode first if transitioning
      if context.coordinator.lastInspectModeState {
        switch oldMode {
        case .crop:
          ElementInspectorBridge.deactivateCrop(in: webView)
        case .input, .context:
          ElementInspectorBridge.deactivate(in: webView)
        }
      }

      context.coordinator.lastInspectModeState = newInspectState
      context.coordinator.lastInspectMode = newMode

      if newInspectState {
        switch newMode {
        case .crop:
          ElementInspectorBridge.activateCrop(in: webView)
        case .input, .context:
          ElementInspectorBridge.activate(in: webView)
        }
      }
    }

    // When the selected element is cleared (nil) while inspect mode is still active,
    // call clearSelection() so hover-following resumes in the JS layer.
    let newSelectedId = selectedElementId
    let oldSelectedId = context.coordinator.lastSelectedElementId
    if oldSelectedId != nil, newSelectedId == nil, newInspectState {
      ElementInspectorBridge.clearSelection(in: webView)
    }
    context.coordinator.lastSelectedElementId = newSelectedId
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private func loadContent(in webView: WKWebView) {
    if isFileURL {
      let readAccessURL = allowingReadAccessTo ?? url.deletingLastPathComponent()
      webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
    } else {
      webView.load(URLRequest(url: url))
    }
  }

  // MARK: - Coordinator

  public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: InspectableWebView
    var lastLoadedURL: URL?
    var lastReloadToken: UUID?
    var lastInspectModeState: Bool = false
    var lastInspectMode: InspectMode = .input
    var lastSelectedElementId: UUID?
    /// Held weakly to avoid retaining the view after dealloc
    weak var webView: WKWebView?

    init(parent: InspectableWebView) {
      self.parent = parent
      self.lastLoadedURL = parent.url
      self.lastReloadToken = parent.reloadToken
      self.lastInspectMode = parent.inspectMode
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      Task { @MainActor in
        parent.onLoadingChange?(true)
      }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      Task { @MainActor in
        parent.onLoadingChange?(false)
        parent.onURLChange?(webView.url)
        lastLoadedURL = parent.url
      }
      // Re-activate inspector after HMR/page reload if still active
      if parent.isInspectModeActive?.wrappedValue == true {
        switch parent.inspectMode {
        case .crop:
          ElementInspectorBridge.activateCrop(in: webView)
        case .input, .context:
          ElementInspectorBridge.activate(in: webView)
        }
      }

      // Restore selection by scrolling to the previously selected element
      if let selector = parent.selectorToRestore, !selector.isEmpty {
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(500))
          ElementInspectorBridge.scrollToElement(selector: selector, in: webView)
        }
      }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      Task { @MainActor in
        parent.onLoadingChange?(false)
        parent.onError?(error.localizedDescription)
      }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      Task { @MainActor in
        parent.onLoadingChange?(false)
        parent.onError?(error.localizedDescription)
      }
    }

    // MARK: WKScriptMessageHandler

    public func userContentController(
      _: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      guard
        message.name == ElementInspectorBridge.messageName,
        let body = message.body as? [String: Any]
      else { return }

      if let messageType = body["type"] as? String {
        switch messageType {
        case "selectionRect":
          let rect = ElementInspectorBridge.parseSelectionRect(body)
          Task { @MainActor in
            parent.onSelectedElementViewportRectChange?(rect)
          }
          return

        case "cropRect":
          let (rect, elements) = ElementInspectorBridge.parseCropData(body)
          Task { @MainActor in
            parent.onCropRectSelected?(rect, elements)
          }
          return

        case "cropRectUpdate":
          let rect = ElementInspectorBridge.parseCropRect(body)
          Task { @MainActor in
            parent.onCropRectViewportChange?(rect)
          }
          return

        default:
          break
        }
      }

      Task { @MainActor in
        let element = ElementInspectorBridge.parseElementData(body)
        parent.onElementSelected?(element)
      }
    }
  }
}
