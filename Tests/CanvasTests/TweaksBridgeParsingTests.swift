import Testing
@testable import Canvas

@Suite("TweaksBridge parsing")
struct TweaksBridgeParsingTests {

  private func makeBody(
    order: [String]? = nil,
    schema: [String: Any]
  ) -> [String: Any] {
    var body: [String: Any] = ["type": "setProps", "schema": schema]
    if let order {
      body["order"] = order
    }
    return body
  }

  @Test func parsesAllPropTypesInDeclaredOrder() {
    let body = makeBody(
      order: ["warmth", "vibe", "accent", "night", "headline"],
      schema: [
        "warmth": ["label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60],
        "vibe": ["label": "Vibe", "type": "select", "options": ["calm", "electric"], "value": "calm"],
        "accent": ["label": "Accent", "type": "color", "value": "#ff6b35"],
        "night": ["label": "Night", "type": "toggle", "value": true],
        "headline": ["label": "Headline", "type": "text", "value": "Hello"],
      ]
    )
    let props = TweaksBridge.parseSchema(body)
    #expect(props.map(\.name) == ["warmth", "vibe", "accent", "night", "headline"])
    #expect(props[0].value == .number(60))
    #expect(props[0].minimum == 0)
    #expect(props[0].maximum == 100)
    #expect(props[0].step == 1)
    #expect(props[1].value == .string("calm"))
    #expect(props[1].options == ["calm", "electric"])
    #expect(props[2].value == .string("#ff6b35"))
    #expect(props[3].value == .boolean(true))
    #expect(props[4].value == .string("Hello"))
  }

  @Test func fallsBackToSortedKeysWhenOrderMissing() {
    let body = makeBody(schema: [
      "b": ["type": "toggle", "value": true],
      "a": ["type": "toggle", "value": false],
    ])
    #expect(TweaksBridge.parseSchema(body).map(\.name) == ["a", "b"])
  }

  @Test func dropsMalformedEntriesIndividually() {
    let body = makeBody(
      order: ["good", "unknownType", "sliderWithStringValue", "selectWithoutOptions", "missingValue"],
      schema: [
        "good": ["type": "toggle", "value": true],
        "unknownType": ["type": "dial", "value": 3],
        "sliderWithStringValue": ["type": "slider", "value": "fast"],
        "selectWithoutOptions": ["type": "select", "value": "calm"],
        "missingValue": ["type": "text"],
      ]
    )
    #expect(TweaksBridge.parseSchema(body).map(\.name) == ["good"])
  }

  @Test func labelFallsBackToPropName() {
    let body = makeBody(schema: ["warmth": ["type": "slider", "value": 5]])
    #expect(TweaksBridge.parseSchema(body).first?.label == "warmth")
  }

  @Test func ignoresNonSetPropsMessages() {
    #expect(TweaksBridge.parseSchema(["type": "other"]).isEmpty)
    #expect(TweaksBridge.parseSchema([:]).isEmpty)
  }

  // MARK: - Native → page push

  @Test func setPropJavaScriptSerializesValues() throws {
    let numberScript = try #require(TweaksBridge.setPropJavaScript(name: "warmth", value: .number(80)))
    #expect(numberScript.contains("window.__canvasTweaks && window.__canvasTweaks.setProp("))
    #expect(numberScript.contains("\"value\":80"))

    let boolScript = try #require(TweaksBridge.setPropJavaScript(name: "night", value: .boolean(true)))
    #expect(boolScript.contains("\"value\":true"))
  }

  @Test func setPropJavaScriptEscapesScriptBreakingStrings() throws {
    let script = try #require(
      TweaksBridge.setPropJavaScript(name: "headline", value: .string("Say \"hi\"\n'); alert(1); ('"))
    )
    // JSONSerialization escapes quotes and newlines so the payload cannot break out.
    #expect(script.contains("\\\"hi\\\""))
    #expect(script.contains("\\n"))
    #expect(!script.contains("\n"))
  }

  // MARK: - Injected script

  @Test func tweaksScriptDefinesRuntimeContract() {
    let js = TweaksBridge.tweaksJS
    #expect(js.contains("window.dc_set_props = function"))
    #expect(js.contains("hasDeclaredProps = true"))
    #expect(js.contains("hasDeclaredProps: function()"))
    #expect(js.contains("window.webkit.messageHandlers.canvasTweaks.postMessage"))
    #expect(js.contains("order: order"))
    #expect(js.contains("window.dc_on_props_changed"))
    #expect(js.contains("dc:propschange"))
    #expect(js.contains("window.__canvasTweaks"))
  }
}
