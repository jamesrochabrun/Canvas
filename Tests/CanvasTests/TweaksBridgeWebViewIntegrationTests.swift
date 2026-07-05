import Testing
import WebKit
@testable import Canvas

/// Captures the first tweaks schema message posted by the page.
private final class CapturingTweaksHandler: NSObject, WKScriptMessageHandler {
  private var continuation: CheckedContinuation<[TweakProp], Never>?
  private var captured: [TweakProp]?

  func userContentController(
    _ controller: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == TweaksBridge.messageName,
          let body = message.body as? [String: Any] else { return }
    let props = TweaksBridge.parseSchema(body)
    if let continuation {
      self.continuation = nil
      continuation.resume(returning: props)
    } else {
      captured = props
    }
  }

  func waitForProps() async -> [TweakProp] {
    if let captured { return captured }
    return await withCheckedContinuation { continuation = $0 }
  }
}

@Suite("TweaksBridge live web view", .serialized)
@MainActor
struct TweaksBridgeWebViewIntegrationTests {

  @Test(.timeLimit(.minutes(1)))
  func schemaPostsToNativeAndSetPropRoundTrips() async throws {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.addUserScript(TweaksBridge.makeUserScript())
    let handler = CapturingTweaksHandler()
    TweaksBridge.registerMessageHandler(on: configuration.userContentController, delegate: handler)

    let webView = WKWebView(frame: .init(x: 0, y: 0, width: 100, height: 100), configuration: configuration)
    let html = """
      <html><body>
      <script>
        dc_set_props({
          "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "value": 60 },
          "night": { "label": "Night", "type": "toggle", "value": false }
        });
        window.__renderCount = 0;
        function render() { window.__renderCount += 1; }
        dc_on_props_changed = render;
        render();
      </script>
      </body></html>
      """
    webView.loadHTMLString(html, baseURL: nil)

    // Page → native: declared schema arrives with order intact.
    let props = await handler.waitForProps()
    #expect(props.map(\.name) == ["warmth", "night"])
    #expect(props.first?.value == .number(60))

    // Native → page: setProp updates window.props and re-invokes the render callback.
    TweaksBridge.setProp(name: "warmth", value: .number(85), in: webView)
    var updated: Double?
    for _ in 0..<50 {
      if let value = try? await webView.evaluateJavaScript("window.props.warmth") as? NSNumber,
         value.doubleValue == 85 {
        updated = value.doubleValue
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(updated == 85)

    let renderCount = try await webView.evaluateJavaScript("window.__renderCount") as? NSNumber
    #expect((renderCount?.intValue ?? 0) >= 2)
  }
}
