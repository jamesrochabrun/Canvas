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

  // MARK: - Inspector JavaScript

  // swiftlint:disable:next function_body_length
  private static func inspectorJS(for dataLevel: ElementInspectorDataLevel) -> String {
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

        function buildCSSSelector(el) {
          var parts = [];
          var node = el;
          var maxDepth = 8;
          while (node && node !== document.body && parts.length < maxDepth) {
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

        __RELATIONSHIP_HELPERS__
        function captureElementData(el) {
          var styles = window.getComputedStyle(el);
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
            boundingRect: captureBoundingRect(el)__CONTEXT_FIELDS__
          };
        }

        function captureBoundingRect(el) {
          var rect = el.getBoundingClientRect();
          return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
        }

        function createOverlay() {
          if (overlay) return;
          overlay = document.createElement('div');
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
          tagLabel = document.createElement('span');
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
          document.body.appendChild(overlay);
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
          selectedElement = null;
          if (currentTarget) highlightElement(currentTarget);
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
        }

        function activate() {
          if (isActive) return;
          isActive = true;
          createOverlay();
          document.addEventListener('mousemove', onMouseMove, true);
          document.addEventListener('click', onClick, true);
          window.addEventListener('scroll', onScroll, { capture: true, passive: true });
          window.addEventListener('resize', onResize, { passive: true });
          document.body.style.cursor = 'crosshair';
        }

        function deactivate() {
          if (!isActive) return;
          isActive = false;
          document.removeEventListener('mousemove', onMouseMove, true);
          document.removeEventListener('click', onClick, true);
          window.removeEventListener('scroll', onScroll, true);
          window.removeEventListener('resize', onResize);
          document.body.style.cursor = '';
          if (overlay) {
            overlay.style.display = 'none';
          }
          if (selectionRectFrame !== null) {
            window.cancelAnimationFrame(selectionRectFrame);
            selectionRectFrame = null;
          }
          currentTarget = null;
          selectedElement = null;
        }

        function scrollToAndSelect(selector) {
          var el;
          try { el = document.querySelector(selector); } catch(e) {}
          if (!el) {
            var simplified = selector.replace(/:[a-z-]+\\([^)]*\\)/g, '').replace(/\\.(?:visible|active|show|open|loaded|animated|entered|in-view)\\b/g, '').replace(/\\s*>\\s*>/g, ' > ').trim();
            if (simplified && simplified !== selector) {
              try { el = document.querySelector(simplified); } catch(e2) {}
            }
          }
          if (!el) return;
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
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
          var all = document.body.querySelectorAll('*');

          for (var i = 0; i < all.length; i++) {
            var el = all[i];
            if (el === cropOverlay) continue;
            if (skipTags[el.tagName]) continue;
            var s = window.getComputedStyle(el);
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
            var centerEl = document.elementFromPoint(cx + cw / 2, cy + ch / 2);
            var ancestor = centerEl;
            while (ancestor && ancestor !== document.body && ancestor !== document.documentElement) {
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
            if (centerEl && centerEl !== cropOverlay && centerEl !== document.body) {
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
          var vx = cropDocX - window.scrollX;
          var vy = cropDocY - window.scrollY;
          try {
            window.webkit.messageHandlers.elementInspector.postMessage({
              type: 'cropRectUpdate',
              boundingRect: { x: vx, y: vy, width: cropWidth, height: cropHeight }
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
          var vx = cropDocX - window.scrollX;
          var vy = cropDocY - window.scrollY;
          cropOverlay.style.left = vx + 'px';
          cropOverlay.style.top = vy + 'px';
          scheduleCropRectPost();
        }

        function onCropResize() {
          if (!cropOverlay || cropOverlay.style.display === 'none') return;
          scheduleCropRectPost();
        }

        function removeCropScrollListeners() {
          window.removeEventListener('scroll', onCropScroll, true);
          window.removeEventListener('resize', onCropResize);
          if (cropRectFrame !== null) {
            window.cancelAnimationFrame(cropRectFrame);
            cropRectFrame = null;
          }
        }

        function createCropOverlay() {
          if (cropOverlay) return;
          cropOverlay = document.createElement('div');
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
          document.body.appendChild(cropOverlay);
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
            cropDocX = x + window.scrollX;
            cropDocY = y + window.scrollY;
            cropWidth = w;
            cropHeight = h;
            window.addEventListener('scroll', onCropScroll, { capture: true, passive: true });
            window.addEventListener('resize', onCropResize, { passive: true });
            var elementsInRect = findElementsInRect(x, y, w, h);
            var elementDataArray = elementsInRect.map(function(el) {
              return captureElementData(el);
            });
            try {
              window.webkit.messageHandlers.elementInspector.postMessage({
                type: 'cropRect',
                boundingRect: { x: x, y: y, width: w, height: h },
                elements: elementDataArray
              });
            } catch(err) {}
          } else {
            if (cropOverlay) cropOverlay.style.display = 'none';
          }
        }

        function activateCrop() {
          if (cropModeActive) return;
          cropModeActive = true;
          createCropOverlay();
          document.addEventListener('mousedown', onCropMouseDown, true);
          document.addEventListener('mousemove', onCropMouseMove, true);
          document.addEventListener('mouseup', onCropMouseUp, true);
          document.body.style.cursor = 'crosshair';
        }

        function deactivateCrop() {
          if (!cropModeActive) return;
          cropModeActive = false;
          isCropDragging = false;
          document.removeEventListener('mousedown', onCropMouseDown, true);
          document.removeEventListener('mousemove', onCropMouseMove, true);
          document.removeEventListener('mouseup', onCropMouseUp, true);
          removeCropScrollListeners();
          document.body.style.cursor = '';
          if (cropOverlay) {
            cropOverlay.style.display = 'none';
          }
        }

        function clearCropSelection() {
          isCropDragging = false;
          removeCropScrollListeners();
          if (cropOverlay) {
            cropOverlay.style.display = 'none';
          }
        }

        window.__elementInspector = { activate: activate, deactivate: deactivate, clearSelection: clearSelection, scrollToAndSelect: scrollToAndSelect, activateCrop: activateCrop, deactivateCrop: deactivateCrop, clearCropSelection: clearCropSelection };
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
          if (parentEl && parentEl !== document.body && parentEl !== document.documentElement) {
            var ps = window.getComputedStyle(parentEl);
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
