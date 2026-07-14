//
//  TweaksBridge.swift
//  WebInspector
//
//  WebKit integration for tweakable props: injects the `dc_set_props`
//  runtime into the page, parses declared schemas posted back to native,
//  and pushes value changes into the running page.
//

import Foundation
import WebKit

/// Public API for integrating tweakable props into a WKWebView.
///
/// The injected script defines `window.dc_set_props(schema)` before any page
/// script runs. Pages declare props with it and read current values via
/// `this.props.<name>`; native value changes re-invoke the page's
/// `dc_on_props_changed` callback.
public enum TweaksBridge {

  /// Message handler name used by the JS bridge.
  public static let messageName = "canvasTweaks"

  /// WKUserScript installing the `dc_set_props` runtime.
  ///
  /// Injected at document start so the function exists before page scripts
  /// execute; it persists across reloads, so the page re-declares its schema
  /// on every load (which is the schema refresh mechanism). Injected into
  /// every frame (not just the main frame) so pages hosted inside a
  /// same-origin content iframe — e.g. a dev-shell preview — can declare
  /// their schema too; `postMessage` reaches the registered handler from
  /// any frame.
  public static func makeUserScript() -> WKUserScript {
    WKUserScript(
      source: tweaksJS,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
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

  /// Parses the dictionary posted from the page's `dc_set_props` call.
  ///
  /// Malformed entries (unknown type, missing or mistyped value) are dropped
  /// individually so one bad prop doesn't take down the whole panel.
  public static func parseSchema(_ body: [String: Any]) -> [TweakProp] {
    guard body["type"] as? String == "setProps",
          let schema = body["schema"] as? [String: Any] else {
      return []
    }
    // WKScriptMessage dictionaries lose key order; the script sends it explicitly.
    let order = (body["order"] as? [Any])?.compactMap { $0 as? String } ?? schema.keys.sorted()
    return order.compactMap { name in
      guard let declaration = schema[name] as? [String: Any] else { return nil }
      return parseProp(name: name, declaration: declaration)
    }
  }

  /// Pushes an updated prop value into the running page.
  public static func setProp(name: String, value: TweakPropValue, in webView: WKWebView) {
    guard let script = setPropJavaScript(name: name, value: value) else { return }
    webView.evaluateJavaScript(script) { _, _ in }
  }

  /// Reports whether the current document called `dc_set_props` during load.
  ///
  /// Checks the top window first, then every same-origin content iframe, so
  /// schemas declared by a framed page are detected too.
  @MainActor
  public static func hasDeclaredProps(in webView: WKWebView) async -> Bool {
    await withCheckedContinuation { continuation in
      webView.evaluateJavaScript(hasDeclaredPropsJavaScript) { result, _ in
        continuation.resume(returning: result as? Bool ?? false)
      }
    }
  }

  /// Expression evaluated in the main frame to detect a declared schema in
  /// the top window or any same-origin content iframe. Cross-origin frames
  /// throw on `contentWindow` access and safely count as undeclared.
  static let hasDeclaredPropsJavaScript = """
    (function() { \
    var declared = function(win) { \
    try { return Boolean(win && win.__canvasTweaks && win.__canvasTweaks.hasDeclaredProps()); } \
    catch (err) { return false; } \
    }; \
    if (declared(window)) { return true; } \
    var frames = document.querySelectorAll('iframe'); \
    for (var i = 0; i < frames.length; i += 1) { \
    if (declared(frames[i].contentWindow)) { return true; } \
    } \
    return false; \
    })();
    """

  static func setPropJavaScript(name: String, value: TweakPropValue) -> String? {
    let payload: [String: Any] = ["name": name, "value": value.bridgeJSONValue]
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
          let json = String(data: data, encoding: .utf8) else {
      return nil
    }
    // Applies the payload to the top window and every same-origin content
    // iframe; cross-origin frames throw on access and are skipped.
    return """
      (function() { \
      var payload = \(json); \
      var apply = function(win) { \
      try { if (win && win.__canvasTweaks) { win.__canvasTweaks.setProp(payload); } } \
      catch (err) {} \
      }; \
      apply(window); \
      var frames = document.querySelectorAll('iframe'); \
      for (var i = 0; i < frames.length; i += 1) { \
      apply(frames[i].contentWindow); \
      } \
      })();
      """
  }

  private static func parseProp(name: String, declaration: [String: Any]) -> TweakProp? {
    guard let typeString = declaration["type"] as? String,
          let type = TweakPropType(rawValue: typeString) else {
      return nil
    }
    let label = (declaration["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? name
    let rawValue = declaration["value"]

    let value: TweakPropValue
    switch type {
    case .slider:
      guard let number = rawValue as? NSNumber else { return nil }
      value = .number(number.doubleValue)
    case .toggle:
      guard let flag = rawValue as? Bool else { return nil }
      value = .boolean(flag)
    case .select, .color, .text:
      guard let string = rawValue as? String else { return nil }
      value = .string(string)
    }

    let options = (declaration["options"] as? [Any])?.compactMap { $0 as? String } ?? []
    if type == .select, options.isEmpty { return nil }

    return TweakProp(
      name: name,
      label: label,
      type: type,
      minimum: (declaration["min"] as? NSNumber)?.doubleValue,
      maximum: (declaration["max"] as? NSNumber)?.doubleValue,
      step: (declaration["step"] as? NSNumber)?.doubleValue,
      options: options,
      value: value
    )
  }

  // MARK: - Tweaks JavaScript

  static let tweaksJS = """
    (function() {
      if (window.__canvasTweaks) { return; }
      var hasDeclaredProps = false;
      window.props = window.props || {};
      window.dc_set_props = function(schema) {
        if (!schema || typeof schema !== 'object') { return; }
        hasDeclaredProps = true;
        var order = Object.keys(schema);
        var props = {};
        order.forEach(function(name) {
          var decl = schema[name] || {};
          props[name] = decl.value;
        });
        window.props = props;
        try {
          window.webkit.messageHandlers.canvasTweaks.postMessage({
            type: 'setProps',
            order: order,
            schema: schema
          });
        } catch (err) {}
      };
      window.__canvasTweaks = {
        hasDeclaredProps: function() {
          return hasDeclaredProps;
        },
        setProp: function(payload) {
          if (!payload || typeof payload.name !== 'string') { return; }
          window.props[payload.name] = payload.value;
          try {
            if (typeof window.dc_on_props_changed === 'function') {
              window.dc_on_props_changed(window.props);
            }
            window.dispatchEvent(new CustomEvent('dc:propschange', {
              detail: { name: payload.name, value: payload.value, props: window.props }
            }));
          } catch (err) {}
        }
      };
    })();
    """
}
