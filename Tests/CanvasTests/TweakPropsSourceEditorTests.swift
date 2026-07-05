import Testing
@testable import Canvas

@Suite("TweakPropsSourceEditor")
struct TweakPropsSourceEditorTests {

  private let sampleHTML = """
    <!DOCTYPE html>
    <html>
    <head><title>Bluey Landing</title></head>
    <body>
    <script>
      dc_set_props({
        "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 },
        "vibe": { "label": "Vibe", "type": "select", "options": ["calm", "electric", "retro"], "value": "calm" },
        "accent": { "label": "Accent", "type": "color", "value": "#ff6b35" },
        "night": { "label": "Night mode", "type": "toggle", "value": false }
      });
      function render() {}
      dc_on_props_changed = render;
      render();
    </script>
    </body>
    </html>
    """

  // MARK: - Parsing

  @Test func parsesAllDeclaredProps() throws {
    let props = try TweakPropsSourceEditor.parseProps(fromSource: sampleHTML)
    #expect(props.map(\.name) == ["warmth", "vibe", "accent", "night"])
    #expect(props[0].type == .slider)
    #expect(props[0].minimum == 0)
    #expect(props[0].maximum == 100)
    #expect(props[0].step == 1)
    #expect(props[0].value == .number(60))
    #expect(props[1].options == ["calm", "electric", "retro"])
    #expect(props[2].value == .string("#ff6b35"))
    #expect(props[3].value == .boolean(false))
  }

  @Test func parsesLabelFallingBackToName() throws {
    let source = "dc_set_props({ \"warmth\": { \"type\": \"slider\", \"value\": 5 } });"
    let props = try TweakPropsSourceEditor.parseProps(fromSource: source)
    #expect(props.first?.label == "warmth")
  }

  @Test func toleratesSingleQuotesAndBareKeys() throws {
    let source = """
      dc_set_props({
        warmth: { label: 'Warmth', type: 'slider', min: 0, max: 10, value: 4 },
        vibe: { type: 'select', options: ['a', 'b'], value: 'a' }
      });
      """
    let props = try TweakPropsSourceEditor.parseProps(fromSource: source)
    #expect(props.map(\.name) == ["warmth", "vibe"])
    #expect(props[0].label == "Warmth")
    #expect(props[1].options == ["a", "b"])
  }

  @Test func throwsWhenCallMissing() {
    #expect(throws: TweakPropsSourceEditorError.callNotFound) {
      try TweakPropsSourceEditor.parseProps(fromSource: "<html><body>Hello</body></html>")
    }
  }

  @Test func throwsOnMultipleCalls() {
    let source = """
      dc_set_props({ "a": { "type": "toggle", "value": true } });
      dc_set_props({ "b": { "type": "toggle", "value": false } });
      """
    #expect(throws: TweakPropsSourceEditorError.multipleCalls) {
      try TweakPropsSourceEditor.parseProps(fromSource: source)
    }
  }

  @Test func ignoresOccurrencesInCommentsAndStrings() throws {
    let source = """
      <!-- dc_set_props({ "fake": {} }) -->
      <script>
        // dc_set_props({ "fake": {} })
        /* dc_set_props({ "fake": {} }) */
        var docs = "call dc_set_props({}) to declare";
        dc_set_props({ "real": { "type": "toggle", "value": true } });
      </script>
      """
    let props = try TweakPropsSourceEditor.parseProps(fromSource: source)
    #expect(props.map(\.name) == ["real"])
  }

  @Test func acceptsWindowPrefixAndOptionalChaining() throws {
    let windowed = "window.dc_set_props({ \"a\": { \"type\": \"toggle\", \"value\": true } });"
    #expect(try TweakPropsSourceEditor.parsePropNames(fromSource: windowed) == ["a"])

    let chained = "dc_set_props?.({ \"a\": { \"type\": \"toggle\", \"value\": true } });"
    #expect(try TweakPropsSourceEditor.parsePropNames(fromSource: chained) == ["a"])
  }

  @Test func rejectsOtherPropertyAccessesAndLongerIdentifiers() {
    let propertyAccess = "thing.dc_set_props({ \"a\": { \"type\": \"toggle\", \"value\": true } });"
    #expect(throws: TweakPropsSourceEditorError.callNotFound) {
      try TweakPropsSourceEditor.parsePropNames(fromSource: propertyAccess)
    }

    let longer = "dc_set_props2({ \"a\": { \"type\": \"toggle\", \"value\": true } });"
    #expect(throws: TweakPropsSourceEditorError.callNotFound) {
      try TweakPropsSourceEditor.parsePropNames(fromSource: longer)
    }
  }

  @Test func nonScalarValueIsLiveOnlyButKeepsItsName() throws {
    let source = """
      dc_set_props({
        "computed": { "type": "slider", "value": someVariable },
        "plain": { "type": "toggle", "value": true }
      });
      """
    let names = try TweakPropsSourceEditor.parsePropNames(fromSource: source)
    #expect(names == ["computed", "plain"])

    let props = try TweakPropsSourceEditor.parseProps(fromSource: source)
    #expect(props.map(\.name) == ["plain"])

    #expect(throws: TweakPropsSourceEditorError.nonScalarValue) {
      try TweakPropsSourceEditor.applyingValueEdit(
        propName: "computed",
        newValue: .number(5),
        toSource: source
      )
    }
  }

  // MARK: - Editing

  @Test func editsIntegerSliderValueWithoutDecimalPoint() throws {
    let edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "warmth",
      newValue: .number(80),
      toSource: sampleHTML
    )
    #expect(edited.contains("\"step\": 1, \"value\": 80 }"))
    #expect(!edited.contains("80.0"))
    let props = try TweakPropsSourceEditor.parseProps(fromSource: edited)
    #expect(props.first?.value == .number(80))
  }

  @Test func editsDecimalValue() throws {
    let source = "dc_set_props({ \"speed\": { \"type\": \"slider\", \"value\": 0.5 } });"
    let edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "speed",
      newValue: .number(0.75),
      toSource: source
    )
    #expect(edited.contains("\"value\": 0.75"))
  }

  @Test func editsStringPreservingQuoteStyle() throws {
    let source = "dc_set_props({ vibe: { type: 'select', options: ['calm', 'retro'], value: 'calm' } });"
    let edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "vibe",
      newValue: .string("retro"),
      toSource: source
    )
    #expect(edited.contains("value: 'retro'"))
  }

  @Test func editsToggleAndColorValues() throws {
    var edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "night",
      newValue: .boolean(true),
      toSource: sampleHTML
    )
    #expect(edited.contains("\"type\": \"toggle\", \"value\": true }"))

    edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "accent",
      newValue: .string("#123abc"),
      toSource: edited
    )
    let props = try TweakPropsSourceEditor.parseProps(fromSource: edited)
    #expect(props.first(where: { $0.name == "accent" })?.value == .string("#123abc"))
    #expect(props.first(where: { $0.name == "night" })?.value == .boolean(true))
  }

  @Test func editLeavesEverythingElseByteIdentical() throws {
    let edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "warmth",
      newValue: .number(85),
      toSource: sampleHTML
    )
    let expected = sampleHTML.replacingOccurrences(
      of: "\"step\": 1, \"value\": 60 }",
      with: "\"step\": 1, \"value\": 85 }"
    )
    #expect(edited == expected)
  }

  @Test func escapesQuotesInNewStringValues() throws {
    let source = "dc_set_props({ \"title\": { \"type\": \"text\", \"value\": \"Hello\" } });"
    let edited = try TweakPropsSourceEditor.applyingValueEdit(
      propName: "title",
      newValue: .string("Say \"hi\"\nthere"),
      toSource: source
    )
    let props = try TweakPropsSourceEditor.parseProps(fromSource: edited)
    #expect(props.first?.value == .string("Say \"hi\"\nthere"))
  }

  @Test func throwsWhenPropMissing() {
    #expect(throws: TweakPropsSourceEditorError.propNotFound) {
      try TweakPropsSourceEditor.applyingValueEdit(
        propName: "missing",
        newValue: .number(1),
        toSource: sampleHTML
      )
    }
  }

  @Test func roundTripParseEditParse() throws {
    var source = sampleHTML
    source = try TweakPropsSourceEditor.applyingValueEdit(propName: "warmth", newValue: .number(42), toSource: source)
    source = try TweakPropsSourceEditor.applyingValueEdit(propName: "vibe", newValue: .string("electric"), toSource: source)
    source = try TweakPropsSourceEditor.applyingValueEdit(propName: "night", newValue: .boolean(true), toSource: source)

    let props = try TweakPropsSourceEditor.parseProps(fromSource: source)
    #expect(props.map(\.name) == ["warmth", "vibe", "accent", "night"])
    #expect(props[0].value == .number(42))
    #expect(props[1].value == .string("electric"))
    #expect(props[2].value == .string("#ff6b35"))
    #expect(props[3].value == .boolean(true))
  }
}
