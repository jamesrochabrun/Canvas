//
//  ElementInspectorBridge.swift
//  WebInspector
//
//  Encapsulates all WebKit integration for the element inspector:
//  JS script injection, message handler registration, data parsing,
//  and WKWebView control (activate/deactivate/clearSelection).
//

import Foundation
import WebKit

// MARK: - WeakScriptMessageHandler

/// Proxy that prevents `WKUserContentController` from retaining the real handler
/// (which would create a retain cycle through the WKWebView configuration).
public final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var delegate: WKScriptMessageHandler?

  public init(_ delegate: WKScriptMessageHandler) {
    self.delegate = delegate
  }

  public func userContentController(
    _ controller: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    delegate?.userContentController(controller, didReceive: message)
  }
}

// MARK: - ElementInspectorBridge

/// Public API for integrating the element inspector into a WKWebView.
public enum ElementInspectorBridge {

  /// Message handler name used by the JS bridge.
  public static let messageName = "elementInspector"

  /// WKUserScript that installs the inspector overlay, hover highlight,
  /// click capture, and scroll tracking into the page.
  public static var userScript: WKUserScript {
    makeUserScript(for: .regular)
  }

  /// WKUserScript that installs the inspector overlay using the requested
  /// element data capture level.
  public static func makeUserScript(for dataLevel: ElementInspectorDataLevel) -> WKUserScript {
    WKUserScript(
      source: inspectorJS(for: dataLevel),
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )
  }

  /// Registers the message handler on the given content controller using a
  /// weak proxy to avoid retain cycles.
  public static func registerMessageHandler(
    on controller: WKUserContentController,
    delegate: WKScriptMessageHandler
  ) {
    controller.add(WeakScriptMessageHandler(delegate), name: messageName)
  }

  /// Parses the dictionary sent from JS `postMessage` into an `ElementInspectorData`.
  public static func parseElementData(_ body: [String: Any]) -> ElementInspectorData {
    let styles = body["computedStyles"] as? [String: String] ?? [:]
    let availableFontFamilies = parseStringArray(from: body["availableFontFamilies"])
    let rect = parseRect(from: body)
    let parentContext = body["parentContext"] as? [String: Any]
    let parentTagName = parentContext?["tagName"] as? String ?? ""
    let parentStyles = parentContext?["styles"] as? [String: String] ?? [:]
    let children = parseRelationships(from: body["children"])
    let siblings = parseRelationships(from: body["siblings"])
    return ElementInspectorData(
      id: UUID(),
      tagName: body["tagName"] as? String ?? "",
      elementId: body["elementId"] as? String ?? "",
      className: body["className"] as? String ?? "",
      textContent: body["textContent"] as? String ?? "",
      outerHTML: body["outerHTML"] as? String ?? "",
      cssSelector: body["cssSelector"] as? String ?? "",
      computedStyles: styles,
      availableFontFamilies: availableFontFamilies,
      boundingRect: rect,
      parentTagName: parentTagName,
      parentStyles: parentStyles,
      children: children,
      siblings: siblings
    )
  }

  /// Parses the selected element's latest viewport rect from a rect-only message.
  public static func parseSelectionRect(_ body: [String: Any]) -> CGRect {
    parseRect(from: body)
  }

  /// Parses the crop rectangle from a `cropRect` message.
  public static func parseCropRect(_ body: [String: Any]) -> CGRect {
    parseRect(from: body)
  }

  /// Parses crop data including the rectangle and all elements within it.
  public static func parseCropData(_ body: [String: Any]) -> (CGRect, [ElementInspectorData]) {
    let rect = parseRect(from: body)
    let rawElements = body["elements"] as? [[String: Any]] ?? []
    let elements = rawElements.map { parseElementData($0) }
    return (rect, elements)
  }

  /// Activates the inspector overlay in the web view.
  public static func activate(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.activate()") { _, _ in }
  }

  /// Deactivates the inspector overlay in the web view.
  public static func deactivate(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.deactivate()") { _, _ in }
  }

  /// Clears the current selection so hover-following resumes.
  public static func clearSelection(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.clearSelection()") { _, _ in }
  }

  /// Activates crop mode (drag-to-select) in the web view.
  public static func activateCrop(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.activateCrop()") { _, _ in }
  }

  /// Deactivates crop mode in the web view.
  public static func deactivateCrop(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.deactivateCrop()") { _, _ in }
  }

  /// Clears the current crop selection so the user can draw a new one.
  public static func clearCropSelection(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.clearCropSelection()") { _, _ in }
  }

  /// Scrolls the page so the element matching the CSS selector is centered in view.
  /// No-ops gracefully if the selector matches nothing.
  public static func scrollToElement(selector: String, in webView: WKWebView) {
    let escaped = selector
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "'", with: "\\'")
    webView.evaluateJavaScript(
      "window.__elementInspector?.scrollToAndSelect('\(escaped)')"
    ) { _, _ in }
  }

  /// Applies a toolbar design edit to the currently selected DOM element.
  public static func applyDesignEdit(_ edit: DesignEdit, in webView: WKWebView) {
    guard let script = designEditJavaScript(for: edit) else { return }
    webView.evaluateJavaScript(script) { _, _ in }
  }

  /// Requests a fresh data capture for the currently selected DOM element.
  public static func refreshSelectedElement(in webView: WKWebView) {
    webView.evaluateJavaScript("window.__elementInspector?.refreshSelectedElement()") { _, _ in }
  }

  static func designEditJavaScript(for edit: DesignEdit) -> String? {
    guard let payload = designEditPayload(for: edit),
          JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
          let json = String(data: data, encoding: .utf8) else {
      return nil
    }
    return "window.__elementInspector?.applyDesignEdit(\(json))"
  }

  private static func designEditPayload(for edit: DesignEdit) -> [String: String]? {
    switch edit.action {
    case .updateProperty(let property, value: let value):
      [
        "type": "updateProperty",
        "property": property.rawValue,
        "value": value,
      ]
    case .updateTextContent(let value):
      [
        "type": "updateTextContent",
        "value": value,
      ]
    case .fitContent:
      [
        "type": "fitContent",
      ]
    case .deleteElement:
      nil
    }
  }

  // MARK: - Inspector JavaScript

  /// CSS selectors used to locate a same-origin `<iframe>` hosting the actual
  /// content to inspect. When such a frame is present and its document is
  /// accessible, inspection targets that document instead of the top one;
  /// otherwise behavior is unchanged. Hosts opt in by tagging their frame
  /// with `data-canvas-content-frame`.
  static let defaultContentFrameSelectors = [
    "iframe[data-canvas-content-frame]"
  ]

  // swiftlint:disable:next function_body_length
  static func inspectorJS(for dataLevel: ElementInspectorDataLevel) -> String {
    let styleKeys = javaScriptArrayLiteral(dataLevel.styleKeys)
    let relationshipHelpers = dataLevel.includesExtendedContext ? fullRelationshipHelpers : ""
    let parentContextCapture = dataLevel.includesExtendedContext ? fullParentContextCapture : "        var parentData = null;"
    let contextFields = dataLevel.includesExtendedContext ? """
,
          parentContext: parentData,
          children: captureChildrenSummary(el),
          siblings: captureSiblings(el)
""" : ""

    var script = """
      (function() {
        var overlay = null;
        var tagLabel = null;
        var currentTarget = null;
        var selectedElement = null;
        var isActive = false;
        var selectionRectFrame = null;
        var selectedElementDataFrame = null;
        var selectedElementObserver = null;
        var fontFamiliesCache = null;
        var fontFamiliesCacheTime = 0;

        // --- Content-frame targeting ---
        // When the top document is only a shell around a same-origin iframe that
        // hosts the real content, inspection targets the iframe's document.
        // Rects posted to native code are translated back into top-frame
        // viewport coordinates.
        var CONTENT_FRAME_SELECTORS = \(javaScriptArrayLiteral(defaultContentFrameSelectors));
        var ctx = null;                 // { doc, win, frameEl } resolved lazily
        var elementListenersCtx = null; // { doc, win } element-mode listeners are bound to
        var cropListenersCtx = null;    // { doc, win } crop-mode listeners are bound to
        var cropScrollCtx = null;       // { win } crop scroll/resize listeners are bound to
        var frameLoadEl = null;         // frame element carrying the 'load' listener
        var frameResizeObserver = null;

        function findContentFrame() {
          for (var i = 0; i < CONTENT_FRAME_SELECTORS.length; i += 1) {
            var frame = null;
            try { frame = document.querySelector(CONTENT_FRAME_SELECTORS[i]); } catch (err) {}
            if (frame) return frame;
          }
          return null;
        }

        function resolveInspectionContext() {
          var frame = findContentFrame();
          if (frame) {
            try {
              var frameDoc = frame.contentDocument;
              var frameWin = frame.contentWindow;
              if (frameDoc && frameWin) {
                return { doc: frameDoc, win: frameWin, frameEl: frame };
              }
            } catch (err) {}
            // Cross-origin or detached frame: fall back to top-document inspection.
          }
          return { doc: document, win: window, frameEl: null };
        }

        function inspectedDoc() { return (ctx && ctx.doc) ? ctx.doc : document; }
        function inspectedWin() { return (ctx && ctx.win) ? ctx.win : window; }

        function getComputedStyleFor(el) {
          var view = (el.ownerDocument && el.ownerDocument.defaultView) || window;
          return view.getComputedStyle(el);
        }

        function frameContentOffset() {
          if (!ctx || !ctx.frameEl) return { x: 0, y: 0 };
          try {
            var r = ctx.frameEl.getBoundingClientRect();
            return {
              x: r.left + (ctx.frameEl.clientLeft || 0),
              y: r.top + (ctx.frameEl.clientTop || 0)
            };
          } catch (err) {
            return { x: 0, y: 0 };
          }
        }

        function toTopViewportRect(rect) {
          var offset = frameContentOffset();
          return { x: rect.x + offset.x, y: rect.y + offset.y, width: rect.width, height: rect.height };
        }

        if (
          document.fonts &&
          document.fonts.ready &&
          typeof document.fonts.ready.then === 'function'
        ) {
          document.fonts.ready.then(function() {
            fontFamiliesCache = null;
          }).catch(function() {});
        }

        function buildCSSSelector(el) {
          var parts = [];
          var node = el;
          var maxDepth = 8;
          var rootBody = (el.ownerDocument || document).body;
          while (node && node !== rootBody && parts.length < maxDepth) {
            var part = node.tagName.toLowerCase();
            if (node.id) {
              part = '#' + node.id;
              parts.unshift(part);
              break;
            }
            if (node.className && typeof node.className === 'string') {
              var classes = node.className.trim().split(/\\s+/).filter(function(c) { return c.length > 0; });
              if (classes.length > 0) {
                part += '.' + classes.slice(0, 2).join('.');
              }
            }
            var siblings = node.parentElement ? Array.from(node.parentElement.children).filter(function(s) {
              return s.tagName === node.tagName;
            }) : [];
            if (siblings.length > 1) {
              var idx = siblings.indexOf(node) + 1;
              part += ':nth-of-type(' + idx + ')';
            }
            parts.unshift(part);
            node = node.parentElement;
          }
          return parts.join(' > ') || el.tagName.toLowerCase();
        }

        function addFontFamilyValue(value, result, seen) {
          if (typeof value !== 'string') return;
          var name = value.trim();
          if (!name) return;

          var first = name.charAt(0);
          var last = name.charAt(name.length - 1);
          if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
            name = name.slice(1, -1).trim();
          }

          if (!name || /^var\\s*\\(/i.test(name)) return;

          var lower = name.toLowerCase();
          if (
            lower === 'inherit' ||
            lower === 'initial' ||
            lower === 'unset' ||
            lower === 'revert' ||
            lower === 'revert-layer'
          ) {
            return;
          }

          if (seen[lower]) return;
          seen[lower] = true;
          result.push(name);
        }

        function addFontFamiliesFromList(list, result, seen) {
          if (typeof list !== 'string') return;

          var part = '';
          var quote = null;
          var parenDepth = 0;

          for (var i = 0; i < list.length; i += 1) {
            var ch = list.charAt(i);
            if (quote) {
              if (ch === quote) quote = null;
              part += ch;
              continue;
            }

            if (ch === '"' || ch === "'") {
              quote = ch;
              part += ch;
              continue;
            }

            if (ch === '(') {
              parenDepth += 1;
              part += ch;
              continue;
            }

            if (ch === ')' && parenDepth > 0) {
              parenDepth -= 1;
              part += ch;
              continue;
            }

            if (ch === ',' && parenDepth === 0) {
              addFontFamilyValue(part, result, seen);
              part = '';
              continue;
            }

            part += ch;
          }

          addFontFamilyValue(part, result, seen);
        }

        function collectPageFontFamilies() {
          var now = Date.now ? Date.now() : new Date().getTime();
          if (fontFamiliesCache !== null && now - fontFamiliesCacheTime < 3000) {
            return fontFamiliesCache.slice();
          }

          var result = [];
          var seen = Object.create(null);
          var doc = inspectedDoc();

          if (doc.fonts && typeof doc.fonts.forEach === 'function') {
            try {
              doc.fonts.forEach(function(face) {
                addFontFamilyValue(face.family, result, seen);
              });
            } catch (err) {}
          }

          var inspectedRules = 0;
          var maxRules = 1500;

          function walkRules(rules) {
            if (!rules || inspectedRules >= maxRules) return;
            for (var i = 0; i < rules.length && inspectedRules < maxRules; i += 1) {
              inspectedRules += 1;
              var rule = rules[i];
              try {
                if (rule.style) {
                  addFontFamiliesFromList(
                    rule.style.fontFamily || rule.style.getPropertyValue('font-family'),
                    result,
                    seen
                  );
                }
                if (rule.cssRules) {
                  walkRules(rule.cssRules);
                }
              } catch (err) {}
            }
          }

          var sheets = doc.styleSheets || [];
          for (var s = 0; s < sheets.length && inspectedRules < maxRules; s += 1) {
            try {
              walkRules(sheets[s].cssRules);
            } catch (err) {}
          }

          fontFamiliesCache = result.slice(0, 80);
          fontFamiliesCacheTime = now;
          return fontFamiliesCache.slice();
        }

        function collectAvailableFontFamilies(selectedFontFamily) {
          var result = [];
          var seen = Object.create(null);
          addFontFamiliesFromList(selectedFontFamily, result, seen);
          collectPageFontFamilies().forEach(function(family) {
            addFontFamilyValue(family, result, seen);
          });
          return result.slice(0, 80);
        }

        __RELATIONSHIP_HELPERS__
        function captureElementData(el) {
          var styles = getComputedStyleFor(el);
          var styleKeys = \(styleKeys);
          var computedStyles = {};
          styleKeys.forEach(function(k) { computedStyles[k] = styles[k] || ''; });
          var text = (el.textContent || '').trim().slice(0, \(dataLevel.textCharacterLimit));
          var html = (el.outerHTML || '').slice(0, \(dataLevel.htmlCharacterLimit));
        __PARENT_CONTEXT_CAPTURE__
          return {
            tagName: el.tagName,
            elementId: el.id || '',
            className: el.className || '',
            textContent: text,
            outerHTML: html,
            cssSelector: buildCSSSelector(el),
            computedStyles: computedStyles,
            availableFontFamilies: collectAvailableFontFamilies(styles.fontFamily || ''),
            boundingRect: captureBoundingRect(el)__CONTEXT_FIELDS__
          };
        }

        function captureBoundingRect(el) {
          var rect = el.getBoundingClientRect();
          // Native code expects top-frame viewport coordinates (WKWebView points).
          return toTopViewportRect({ x: rect.x, y: rect.y, width: rect.width, height: rect.height });
        }

        function createOverlay() {
          var doc = inspectedDoc();
          if (overlay && overlay.ownerDocument !== doc) {
            try { overlay.remove(); } catch (err) {}
            overlay = null;
            tagLabel = null;
          }
          if (overlay) return;
          overlay = doc.createElement('div');
          overlay.style.cssText = [
            'position:fixed',
            'pointer-events:none',
            'z-index:2147483647',
            'box-sizing:border-box',
            'border:2px solid #2563eb',
            'background:rgba(37,99,235,0.08)',
            'border-radius:3px',
            'transition:all 0.08s ease',
            'display:none'
          ].join(';');
          tagLabel = doc.createElement('span');
          tagLabel.style.cssText = [
            'position:absolute',
            'bottom:100%',
            'right:-2px',
            'background:#2563eb',
            'color:#fff',
            'font-size:10px',
            'font-family:-apple-system,BlinkMacSystemFont,sans-serif',
            'line-height:1',
            'padding:2px 5px',
            'border-radius:3px 3px 0 0',
            'white-space:nowrap'
          ].join(';');
          overlay.appendChild(tagLabel);
          if (doc.body) doc.body.appendChild(overlay);
        }

        function highlightElement(el) {
          if (!overlay || !el) return;
          var rect = el.getBoundingClientRect();
          overlay.style.left = rect.left + 'px';
          overlay.style.top = rect.top + 'px';
          overlay.style.width = rect.width + 'px';
          overlay.style.height = rect.height + 'px';
          overlay.style.display = 'block';
          if (tagLabel) tagLabel.textContent = el.tagName.toLowerCase();
        }

        function onMouseMove(e) {
          if (!isActive) return;
          if (selectedElement !== null) return;
          var el = e.target;
          if (el === overlay) return;
          currentTarget = el;
          highlightElement(el);
        }

        function onClick(e) {
          if (!isActive) return;
          e.preventDefault();
          e.stopPropagation();
          selectedElement = e.target;
          observeSelectedElement(selectedElement);
          highlightElement(selectedElement);
          var data = captureElementData(e.target);
          try {
            window.webkit.messageHandlers.elementInspector.postMessage(data);
          } catch(err) {}
        }

        function clearSelection() {
          if (selectionRectFrame !== null) {
            window.cancelAnimationFrame(selectionRectFrame);
            selectionRectFrame = null;
          }
          disconnectSelectedElementObserver();
          selectedElement = null;
          if (currentTarget) highlightElement(currentTarget);
        }

        function disconnectSelectedElementObserver() {
          if (selectedElementObserver !== null) {
            selectedElementObserver.disconnect();
            selectedElementObserver = null;
          }
          if (selectedElementDataFrame !== null) {
            window.cancelAnimationFrame(selectedElementDataFrame);
            selectedElementDataFrame = null;
          }
        }

        function observeSelectedElement(el) {
          disconnectSelectedElementObserver();
          if (!el || typeof MutationObserver === 'undefined') return;
          selectedElementObserver = new MutationObserver(function() {
            scheduleSelectedElementDataPost();
          });
          selectedElementObserver.observe(el, {
            attributes: true,
            characterData: true,
            childList: true,
            subtree: true
          });
        }

        function postSelectedElementData() {
          if (!selectedElement) return;
          var data = captureElementData(selectedElement);
          data.type = 'selectedElementDataChange';
          try {
            window.webkit.messageHandlers.elementInspector.postMessage(data);
          } catch(err) {}
        }

        function scheduleSelectedElementDataPost() {
          if (!selectedElement || selectedElementDataFrame !== null) return;
          selectedElementDataFrame = window.requestAnimationFrame(function() {
            selectedElementDataFrame = null;
            postSelectedElementData();
          });
        }

        function postSelectedRect() {
          if (!selectedElement) return;
          try {
            window.webkit.messageHandlers.elementInspector.postMessage({
              type: 'selectionRect',
              boundingRect: captureBoundingRect(selectedElement)
            });
          } catch(err) {}
        }

        function scheduleSelectedRectPost() {
          if (!selectedElement || selectionRectFrame !== null) return;
          selectionRectFrame = window.requestAnimationFrame(function() {
            selectionRectFrame = null;
            postSelectedRect();
          });
        }

        function onScroll() {
          if (!selectedElement) return;
          highlightElement(selectedElement);
          scheduleSelectedRectPost();
        }

        function onResize() {
          if (!selectedElement) return;
          highlightElement(selectedElement);
          scheduleSelectedRectPost();
          scheduleSelectedElementDataPost();
        }

        function attachElementListeners() {
          if (!ctx || !ctx.doc || elementListenersCtx) return;
          var d = ctx.doc;
          var w = ctx.win;
          d.addEventListener('mousemove', onMouseMove, true);
          d.addEventListener('click', onClick, true);
          w.addEventListener('scroll', onScroll, { capture: true, passive: true });
          w.addEventListener('resize', onResize, { passive: true });
          if (w !== window) {
            // Top-frame scroll/resize moves the content frame itself, which
            // shifts the translated rects delivered to native code.
            window.addEventListener('scroll', onScroll, { capture: true, passive: true });
            window.addEventListener('resize', onResize, { passive: true });
          }
          try { if (d.body) d.body.style.cursor = 'crosshair'; } catch (err) {}
          elementListenersCtx = { doc: d, win: w };
        }

        function detachElementListeners() {
          if (!elementListenersCtx) return;
          var d = elementListenersCtx.doc;
          var w = elementListenersCtx.win;
          try {
            d.removeEventListener('mousemove', onMouseMove, true);
            d.removeEventListener('click', onClick, true);
            if (d.body) d.body.style.cursor = '';
          } catch (err) {}
          try {
            w.removeEventListener('scroll', onScroll, true);
            w.removeEventListener('resize', onResize);
          } catch (err) {}
          if (w !== window) {
            window.removeEventListener('scroll', onScroll, true);
            window.removeEventListener('resize', onResize);
          }
          elementListenersCtx = null;
        }

        function onFrameLoad() {
          detachElementListeners();
          detachCropListeners();
          removeCropScrollListeners();
          // Overlay nodes belonged to the unloaded document; recreate lazily.
          overlay = null;
          tagLabel = null;
          cropOverlay = null;
          currentTarget = null;
          selectedElement = null;
          isCropDragging = false;
          disconnectSelectedElementObserver();
          if (selectionRectFrame !== null) {
            window.cancelAnimationFrame(selectionRectFrame);
            selectionRectFrame = null;
          }
          fontFamiliesCache = null;
          ctx = resolveInspectionContext();
          ensureFrameObservers();
          if (isActive) {
            createOverlay();
            attachElementListeners();
          }
          if (cropModeActive) {
            createCropOverlay();
            attachCropListeners();
          }
        }

        function onFrameLayoutChange() {
          onResize();
          onCropResize();
        }

        // When activation happens before the host shell has rendered the
        // content frame, listeners land on the top document. Watch for the
        // frame to appear and rebind the moment it does, without needing the
        // user to toggle inspection off and on. childList-only keeps the
        // observer quiet during overlay updates.
        var frameWatchObserver = null;

        function watchForContentFrame() {
          if (frameWatchObserver || typeof MutationObserver === 'undefined') return;
          frameWatchObserver = new MutationObserver(function() {
            if (!isActive && !cropModeActive) {
              stopWatchingForContentFrame();
              return;
            }
            if (!findContentFrame()) return;
            stopWatchingForContentFrame();
            onFrameLoad();
          });
          frameWatchObserver.observe(document.documentElement, { childList: true, subtree: true });
        }

        function stopWatchingForContentFrame() {
          if (frameWatchObserver) {
            frameWatchObserver.disconnect();
            frameWatchObserver = null;
          }
        }

        function watchForContentFrameIfMissing() {
          if (!ctx || ctx.frameEl || findContentFrame()) return;
          watchForContentFrame();
        }

        function ensureFrameObservers() {
          if (!ctx || !ctx.frameEl || frameLoadEl === ctx.frameEl) return;
          removeFrameObservers();
          frameLoadEl = ctx.frameEl;
          frameLoadEl.addEventListener('load', onFrameLoad);
          if (typeof ResizeObserver !== 'undefined') {
            frameResizeObserver = new ResizeObserver(onFrameLayoutChange);
            frameResizeObserver.observe(frameLoadEl);
          }
        }

        function removeFrameObservers() {
          if (frameLoadEl) {
            frameLoadEl.removeEventListener('load', onFrameLoad);
            frameLoadEl = null;
          }
          if (frameResizeObserver) {
            frameResizeObserver.disconnect();
            frameResizeObserver = null;
          }
        }

        function removeFrameObserversIfIdle() {
          if (!isActive && !cropModeActive) {
            removeFrameObservers();
            stopWatchingForContentFrame();
          }
        }

        function activate() {
          if (isActive) return;
          isActive = true;
          ctx = resolveInspectionContext();
          ensureFrameObservers();
          watchForContentFrameIfMissing();
          createOverlay();
          attachElementListeners();
        }

        function deactivate() {
          if (!isActive) return;
          isActive = false;
          detachElementListeners();
          if (overlay) {
            overlay.style.display = 'none';
          }
          if (selectionRectFrame !== null) {
            window.cancelAnimationFrame(selectionRectFrame);
            selectionRectFrame = null;
          }
          disconnectSelectedElementObserver();
          currentTarget = null;
          selectedElement = null;
          removeFrameObserversIfIdle();
        }

        function scrollToAndSelect(selector) {
          if (!ctx) ctx = resolveInspectionContext();
          ensureFrameObservers();
          var doc = inspectedDoc();
          var el;
          try { el = doc.querySelector(selector); } catch(e) {}
          if (!el) {
            var simplified = selector.replace(/:[a-z-]+\\([^)]*\\)/g, '').replace(/\\.(?:visible|active|show|open|loaded|animated|entered|in-view)\\b/g, '').replace(/\\s*>\\s*>/g, ' > ').trim();
            if (simplified && simplified !== selector) {
              try { el = doc.querySelector(simplified); } catch(e2) {}
            }
          }
          if (!el) return;
          selectedElement = el;
          currentTarget = el;
          observeSelectedElement(selectedElement);
          createOverlay();
          highlightElement(selectedElement);
          scheduleSelectedElementDataPost();
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          window.setTimeout(function() {
            if (selectedElement === el) {
              highlightElement(selectedElement);
              scheduleSelectedRectPost();
              scheduleSelectedElementDataPost();
            }
          }, 400);
        }

        function applyDesignEdit(edit) {
          if (!selectedElement || !edit || typeof edit.type !== 'string') return;

          if (edit.type === 'updateProperty') {
            if (!edit.property || typeof edit.property !== 'string') return;
            var propertyValue = edit.value == null ? '' : String(edit.value);
            if (propertyValue.trim() === '') {
              selectedElement.style.removeProperty(edit.property);
            } else {
              selectedElement.style.setProperty(edit.property, propertyValue);
            }
          } else if (edit.type === 'updateTextContent') {
            replaceTextContentPreservingStructure(selectedElement, edit.value == null ? '' : String(edit.value));
          } else if (edit.type === 'fitContent') {
            selectedElement.style.setProperty('width', 'fit-content');
            selectedElement.style.setProperty('height', 'fit-content');
          } else {
            return;
          }

          highlightElement(selectedElement);
          scheduleSelectedRectPost();
          scheduleSelectedElementDataPost();
        }

        function replaceTextContentPreservingStructure(el, nextText) {
          var walker = (el.ownerDocument || document).createTreeWalker(el, NodeFilter.SHOW_TEXT);
          var nodes = [];
          var node;
          while ((node = walker.nextNode())) {
            nodes.push(node);
          }

          if (nodes.length === 0) {
            el.textContent = nextText;
            return;
          }

          var oldText = nodes.map(function(textNode) {
            return textNode.nodeValue || '';
          }).join('');
          var splice = textSplice(oldText, nextText);
          if (!splice) return;

          if (splice.start === oldText.length) {
            var appendTarget = oldText.length === 0 ? nodes[0] : nodes[nodes.length - 1];
            appendTarget.nodeValue = (appendTarget.nodeValue || '') + splice.replacement;
            return;
          }

          var offset = 0;
          var inserted = false;
          for (var i = 0; i < nodes.length; i += 1) {
            var textNode = nodes[i];
            var text = textNode.nodeValue || '';
            var start = offset;
            var end = offset + text.length;
            offset = end;

            if (end < splice.start || start > splice.end) continue;

            var localStart = Math.max(0, splice.start - start);
            var localEnd = Math.min(text.length, splice.end - start);
            if (!inserted) {
              textNode.nodeValue = text.slice(0, localStart) + splice.replacement + text.slice(localEnd);
              inserted = true;
            } else {
              textNode.nodeValue = text.slice(localEnd);
            }
          }

          if (!inserted) {
            nodes[nodes.length - 1].nodeValue = (nodes[nodes.length - 1].nodeValue || '') + splice.replacement;
          }
        }

        function textSplice(oldText, nextText) {
          if (oldText === nextText) return null;

          var prefix = 0;
          var maxPrefix = Math.min(oldText.length, nextText.length);
          while (prefix < maxPrefix && oldText.charAt(prefix) === nextText.charAt(prefix)) {
            prefix += 1;
          }

          var oldSuffix = oldText.length;
          var nextSuffix = nextText.length;
          while (
            oldSuffix > prefix &&
            nextSuffix > prefix &&
            oldText.charAt(oldSuffix - 1) === nextText.charAt(nextSuffix - 1)
          ) {
            oldSuffix -= 1;
            nextSuffix -= 1;
          }

          return {
            start: prefix,
            end: oldSuffix,
            replacement: nextText.slice(prefix, nextSuffix)
          };
        }

        function refreshSelectedElement() {
          if (!selectedElement) return;
          highlightElement(selectedElement);
          scheduleSelectedRectPost();
          scheduleSelectedElementDataPost();
        }

        // --- Crop mode (drag-to-select region) ---
        var cropModeActive = false;
        var cropOverlay = null;
        var cropStartX = 0;
        var cropStartY = 0;
        var isCropDragging = false;
        var cropDocX = 0;
        var cropDocY = 0;
        var cropWidth = 0;
        var cropHeight = 0;
        var cropRectFrame = null;

        function rectIntersectionArea(a, b) {
          var x1 = Math.max(a.x, b.x);
          var y1 = Math.max(a.y, b.y);
          var x2 = Math.min(a.x + a.width, b.x + b.width);
          var y2 = Math.min(a.y + a.height, b.y + b.height);
          if (x2 <= x1 || y2 <= y1) return 0;
          return (x2 - x1) * (y2 - y1);
        }

        function findElementsInRect(cx, cy, cw, ch) {
          var crop = { x: cx, y: cy, width: cw, height: ch };
          var skipTags = { SCRIPT:1, STYLE:1, HEAD:1, META:1, LINK:1, BR:1, NOSCRIPT:1 };
          var candidates = [];
          var doc = inspectedDoc();
          var all = doc.body.querySelectorAll('*');

          for (var i = 0; i < all.length; i++) {
            var el = all[i];
            if (el === cropOverlay) continue;
            if (skipTags[el.tagName]) continue;
            var s = getComputedStyleFor(el);
            if (s.display === 'none' || s.visibility === 'hidden') continue;
            var r = el.getBoundingClientRect();
            if (r.width === 0 || r.height === 0) continue;
            var elRect = { x: r.x, y: r.y, width: r.width, height: r.height };
            var overlap = rectIntersectionArea(crop, elRect);
            if (overlap === 0) continue;
            var elArea = r.width * r.height;
            var overlapRatio = overlap / elArea;
            if (overlapRatio < 0.3) continue;
            candidates.push({ el: el, overlapRatio: overlapRatio, area: elArea });
          }

          var filtered = candidates.filter(function(c) {
            for (var j = 0; j < candidates.length; j++) {
              if (candidates[j].el !== c.el && c.el.contains(candidates[j].el)) {
                return false;
              }
            }
            return true;
          });

          if (filtered.length === 0) {
            var centerEl = doc.elementFromPoint(cx + cw / 2, cy + ch / 2);
            var ancestor = centerEl;
            while (ancestor && ancestor !== doc.body && ancestor !== doc.documentElement) {
              if (ancestor === cropOverlay) { ancestor = ancestor.parentElement; continue; }
              if (skipTags[ancestor.tagName]) { ancestor = ancestor.parentElement; continue; }
              var ar = ancestor.getBoundingClientRect();
              if (ar.x <= cx && ar.y <= cy &&
                  ar.x + ar.width >= cx + cw &&
                  ar.y + ar.height >= cy + ch) {
                return [ancestor];
              }
              ancestor = ancestor.parentElement;
            }
            if (centerEl && centerEl !== cropOverlay && centerEl !== doc.body) {
              return [centerEl];
            }
            return [];
          }

          filtered.sort(function(a, b) {
            if (b.overlapRatio !== a.overlapRatio) return b.overlapRatio - a.overlapRatio;
            return a.area - b.area;
          });

          return filtered.slice(0, 20).map(function(c) { return c.el; });
        }

        function postCropRectUpdate() {
          var w = inspectedWin();
          var vx = cropDocX - w.scrollX;
          var vy = cropDocY - w.scrollY;
          try {
            window.webkit.messageHandlers.elementInspector.postMessage({
              type: 'cropRectUpdate',
              boundingRect: toTopViewportRect({ x: vx, y: vy, width: cropWidth, height: cropHeight })
            });
          } catch(err) {}
        }

        function scheduleCropRectPost() {
          if (cropRectFrame !== null) return;
          cropRectFrame = window.requestAnimationFrame(function() {
            cropRectFrame = null;
            postCropRectUpdate();
          });
        }

        function onCropScroll() {
          if (!cropOverlay || cropOverlay.style.display === 'none') return;
          var w = inspectedWin();
          var vx = cropDocX - w.scrollX;
          var vy = cropDocY - w.scrollY;
          cropOverlay.style.left = vx + 'px';
          cropOverlay.style.top = vy + 'px';
          scheduleCropRectPost();
        }

        function onCropResize() {
          if (!cropOverlay || cropOverlay.style.display === 'none') return;
          scheduleCropRectPost();
        }

        function addCropScrollListeners() {
          removeCropScrollListeners();
          var w = inspectedWin();
          w.addEventListener('scroll', onCropScroll, { capture: true, passive: true });
          w.addEventListener('resize', onCropResize, { passive: true });
          if (w !== window) {
            window.addEventListener('scroll', onCropScroll, { capture: true, passive: true });
            window.addEventListener('resize', onCropResize, { passive: true });
          }
          cropScrollCtx = { win: w };
        }

        function removeCropScrollListeners() {
          if (cropScrollCtx) {
            try {
              cropScrollCtx.win.removeEventListener('scroll', onCropScroll, true);
              cropScrollCtx.win.removeEventListener('resize', onCropResize);
            } catch (err) {}
            if (cropScrollCtx.win !== window) {
              window.removeEventListener('scroll', onCropScroll, true);
              window.removeEventListener('resize', onCropResize);
            }
            cropScrollCtx = null;
          }
          if (cropRectFrame !== null) {
            window.cancelAnimationFrame(cropRectFrame);
            cropRectFrame = null;
          }
        }

        function createCropOverlay() {
          var doc = inspectedDoc();
          if (cropOverlay && cropOverlay.ownerDocument !== doc) {
            try { cropOverlay.remove(); } catch (err) {}
            cropOverlay = null;
          }
          if (cropOverlay) return;
          cropOverlay = doc.createElement('div');
          cropOverlay.style.cssText = [
            'position:fixed',
            'pointer-events:none',
            'z-index:2147483647',
            'box-sizing:border-box',
            'border:2px dashed rgba(255,160,80,0.9)',
            'background:rgba(255,160,80,0.06)',
            'border-radius:3px',
            'display:none'
          ].join(';');
          if (doc.body) doc.body.appendChild(cropOverlay);
        }

        function onCropMouseDown(e) {
          if (!cropModeActive) return;
          e.preventDefault();
          e.stopPropagation();
          isCropDragging = true;
          cropStartX = e.clientX;
          cropStartY = e.clientY;
          createCropOverlay();
          cropOverlay.style.left = cropStartX + 'px';
          cropOverlay.style.top = cropStartY + 'px';
          cropOverlay.style.width = '0px';
          cropOverlay.style.height = '0px';
          cropOverlay.style.display = 'block';
        }

        function onCropMouseMove(e) {
          if (!cropModeActive || !isCropDragging) return;
          e.preventDefault();
          var x = Math.min(e.clientX, cropStartX);
          var y = Math.min(e.clientY, cropStartY);
          var w = Math.abs(e.clientX - cropStartX);
          var h = Math.abs(e.clientY - cropStartY);
          cropOverlay.style.left = x + 'px';
          cropOverlay.style.top = y + 'px';
          cropOverlay.style.width = w + 'px';
          cropOverlay.style.height = h + 'px';
        }

        function onCropMouseUp(e) {
          if (!cropModeActive || !isCropDragging) return;
          e.preventDefault();
          e.stopPropagation();
          isCropDragging = false;
          var x = Math.min(e.clientX, cropStartX);
          var y = Math.min(e.clientY, cropStartY);
          var w = Math.abs(e.clientX - cropStartX);
          var h = Math.abs(e.clientY - cropStartY);
          if (w > 5 && h > 5) {
            var win = inspectedWin();
            cropDocX = x + win.scrollX;
            cropDocY = y + win.scrollY;
            cropWidth = w;
            cropHeight = h;
            addCropScrollListeners();
            var elementsInRect = findElementsInRect(x, y, w, h);
            var elementDataArray = elementsInRect.map(function(el) {
              return captureElementData(el);
            });
            try {
              window.webkit.messageHandlers.elementInspector.postMessage({
                type: 'cropRect',
                boundingRect: toTopViewportRect({ x: x, y: y, width: w, height: h }),
                elements: elementDataArray
              });
            } catch(err) {}
          } else {
            if (cropOverlay) cropOverlay.style.display = 'none';
          }
        }

        function attachCropListeners() {
          if (!ctx || !ctx.doc || cropListenersCtx) return;
          var d = ctx.doc;
          d.addEventListener('mousedown', onCropMouseDown, true);
          d.addEventListener('mousemove', onCropMouseMove, true);
          d.addEventListener('mouseup', onCropMouseUp, true);
          try { if (d.body) d.body.style.cursor = 'crosshair'; } catch (err) {}
          cropListenersCtx = { doc: d, win: ctx.win };
        }

        function detachCropListeners() {
          if (!cropListenersCtx) return;
          var d = cropListenersCtx.doc;
          try {
            d.removeEventListener('mousedown', onCropMouseDown, true);
            d.removeEventListener('mousemove', onCropMouseMove, true);
            d.removeEventListener('mouseup', onCropMouseUp, true);
            if (d.body) d.body.style.cursor = '';
          } catch (err) {}
          cropListenersCtx = null;
        }

        function activateCrop() {
          if (cropModeActive) return;
          cropModeActive = true;
          ctx = resolveInspectionContext();
          ensureFrameObservers();
          watchForContentFrameIfMissing();
          createCropOverlay();
          attachCropListeners();
        }

        function deactivateCrop() {
          if (!cropModeActive) return;
          cropModeActive = false;
          isCropDragging = false;
          detachCropListeners();
          removeCropScrollListeners();
          if (cropOverlay) {
            cropOverlay.style.display = 'none';
          }
          removeFrameObserversIfIdle();
        }

        function clearCropSelection() {
          isCropDragging = false;
          removeCropScrollListeners();
          if (cropOverlay) {
            cropOverlay.style.display = 'none';
          }
        }

        window.__elementInspector = {
          activate: activate,
          deactivate: deactivate,
          clearSelection: clearSelection,
          scrollToAndSelect: scrollToAndSelect,
          applyDesignEdit: applyDesignEdit,
          refreshSelectedElement: refreshSelectedElement,
          activateCrop: activateCrop,
          deactivateCrop: deactivateCrop,
          clearCropSelection: clearCropSelection
        };
      })();
      """

    script = script.replacingOccurrences(of: "__RELATIONSHIP_HELPERS__", with: relationshipHelpers)
    script = script.replacingOccurrences(of: "__PARENT_CONTEXT_CAPTURE__", with: parentContextCapture)
    script = script.replacingOccurrences(of: "__CONTEXT_FIELDS__", with: contextFields)
    return script
  }

  private static let fullRelationshipHelpers = """
        function captureChildrenSummary(el) {
          var children = Array.from(el.children);
          var count = children.length;
          if (count === 0) return null;
          var items = children.slice(0, 10).map(function(child) {
            var entry = { tagName: child.tagName };
            if (child.id) entry.id = child.id;
            if (child.className && typeof child.className === 'string' && child.className.trim()) {
              entry.className = child.className.trim().split(/\\s+/).slice(0, 3).join(' ');
            }
            var text = (child.textContent || '').trim();
            if (text) entry.textContent = text.slice(0, 50);
            return entry;
          });
          return { count: count, items: items };
        }

        function captureSiblings(el) {
          var parent = el.parentElement;
          if (!parent) return null;
          var siblings = Array.from(parent.children).filter(function(s) { return s !== el; });
          var count = siblings.length;
          if (count === 0) return null;
          var items = siblings.slice(0, 10).map(function(sib) {
            var entry = { tagName: sib.tagName };
            if (sib.id) entry.id = sib.id;
            if (sib.className && typeof sib.className === 'string' && sib.className.trim()) {
              entry.className = sib.className.trim().split(/\\s+/).slice(0, 3).join(' ');
            }
            var text = (sib.textContent || '').trim();
            if (text) entry.textContent = text.slice(0, 50);
            return entry;
          });
          return { count: count, items: items };
        }
  """

  private static let fullParentContextCapture = """
          var parentEl = el.parentElement;
          var parentData = null;
          var ownerDoc = el.ownerDocument || document;
          if (parentEl && parentEl !== ownerDoc.body && parentEl !== ownerDoc.documentElement) {
            var ps = getComputedStyleFor(parentEl);
            var parentKeys = [
              'display','flexDirection','flexWrap','justifyContent',
              'alignItems','alignContent','gap','gridTemplateColumns',
              'gridTemplateRows','position','overflow'
            ];
            var parentStyles = {};
            parentKeys.forEach(function(k) { parentStyles[k] = ps[k] || ''; });
            parentData = { tagName: parentEl.tagName, styles: parentStyles };
          }
  """

  private static func javaScriptArrayLiteral(_ values: [String]) -> String {
    let serializedValues = values.map { "'\($0)'" }.joined(separator: ",")
    return "[\(serializedValues)]"
  }

  private static func parseRelationships(from raw: Any?) -> ElementRelationships {
    guard let dict = raw as? [String: Any],
          let count = dict["count"] as? Int,
          let rawItems = dict["items"] as? [[String: Any]] else {
      return ElementRelationships()
    }
    let items = rawItems.map { item in
      ElementSummary(
        tagName: item["tagName"] as? String ?? "",
        elementId: item["id"] as? String ?? "",
        className: item["className"] as? String ?? "",
        textContent: item["textContent"] as? String ?? ""
      )
    }
    return ElementRelationships(count: count, items: items)
  }

  private static func parseStringArray(from raw: Any?) -> [String] {
    if let values = raw as? [String] {
      return values
    }
    guard let values = raw as? [Any] else {
      return []
    }
    return values.compactMap { $0 as? String }
  }

  private static func parseRect(from body: [String: Any]) -> CGRect {
    let rectDict = body["boundingRect"] as? [String: Double] ?? [:]
    return CGRect(
      x: rectDict["x"] ?? 0,
      y: rectDict["y"] ?? 0,
      width: rectDict["width"] ?? 0,
      height: rectDict["height"] ?? 0
    )
  }
}
