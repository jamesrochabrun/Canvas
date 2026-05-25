import CoreGraphics
import Testing
@testable import Canvas

@Suite("ElementInspectorBridge parsing")
struct ElementInspectorBridgeParsingTests {

  @Test func parsesFullyPopulatedDictionary() {
    let dict: [String: Any] = [
      "tagName": "BUTTON",
      "elementId": "submit",
      "className": "btn primary",
      "textContent": "Go",
      "outerHTML": "<button>Go</button>",
      "cssSelector": "form > button",
      "computedStyles": ["color": "red", "fontSize": "14px"],
      "availableFontFamilies": ["Inter", "Georgia"],
      "boundingRect": ["x": 10.0, "y": 20.0, "width": 100.0, "height": 40.0],
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.tagName == "BUTTON")
    #expect(data.elementId == "submit")
    #expect(data.className == "btn primary")
    #expect(data.textContent == "Go")
    #expect(data.outerHTML == "<button>Go</button>")
    #expect(data.cssSelector == "form > button")
    #expect(data.computedStyles == ["color": "red", "fontSize": "14px"])
    #expect(data.availableFontFamilies == ["Inter", "Georgia"])
    #expect(data.boundingRect == CGRect(x: 10, y: 20, width: 100, height: 40))
  }

  @Test func missingKeysDefaultToEmptyStringsAndZeroRect() {
    let data = ElementInspectorBridge.parseElementData([:])
    #expect(data.tagName == "")
    #expect(data.elementId == "")
    #expect(data.className == "")
    #expect(data.textContent == "")
    #expect(data.outerHTML == "")
    #expect(data.cssSelector == "")
    #expect(data.computedStyles == [:])
    #expect(data.availableFontFamilies == [])
    #expect(data.boundingRect == .zero)
  }

  @Test func partialBoundingRectFillsMissingWithZero() {
    let dict: [String: Any] = [
      "boundingRect": ["x": 5.0, "height": 30.0],
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.boundingRect == CGRect(x: 5, y: 0, width: 0, height: 30))
  }

  @Test func parsesSelectionRectMessage() {
    let rect = ElementInspectorBridge.parseSelectionRect([
      "type": "selectionRect",
      "boundingRect": ["x": 9.0, "y": 11.0, "width": 120.0, "height": 32.0],
    ])

    #expect(rect == CGRect(x: 9, y: 11, width: 120, height: 32))
  }

  @Test func parsesSelectedElementDataChangeMessage() {
    let data = ElementInspectorBridge.parseElementData([
      "type": "selectedElementDataChange",
      "tagName": "H3",
      "textContent": "Updated title",
      "cssSelector": ".feature > h3",
      "computedStyles": ["fontSize": "20px"],
      "boundingRect": ["x": 14.0, "y": 24.0, "width": 220.0, "height": 28.0],
    ])

    #expect(data.tagName == "H3")
    #expect(data.textContent == "Updated title")
    #expect(data.cssSelector == ".feature > h3")
    #expect(data.computedStyles == ["fontSize": "20px"])
    #expect(data.boundingRect == CGRect(x: 14, y: 24, width: 220, height: 28))
  }

  @Test func designEditJavaScriptSerializesEscapedPayload() {
    let edit = DesignEdit(
      element: TestFixtures.makeButton(),
      action: .updateTextContent("Buy \"now\" \\ today\nplease")
    )

    let script = ElementInspectorBridge.designEditJavaScript(for: edit)

    #expect(script?.hasPrefix("window.__elementInspector?.applyDesignEdit(") == true)
    #expect(script?.contains(#""type":"updateTextContent""#) == true)
    #expect(script?.contains(#"Buy \"now\" \\ today\nplease"#) == true)
  }

  @Test func deleteElementDoesNotProduceLiveEditJavaScript() {
    let edit = DesignEdit(
      element: TestFixtures.makeButton(),
      action: .deleteElement
    )

    #expect(ElementInspectorBridge.designEditJavaScript(for: edit) == nil)
  }

  @Test func missingSelectionRectDefaultsToZero() {
    let rect = ElementInspectorBridge.parseSelectionRect(["type": "selectionRect"])
    #expect(rect == .zero)
  }

  @Test func missingComputedStylesDefaultsToEmptyDict() {
    let data = ElementInspectorBridge.parseElementData([:])
    #expect(data.computedStyles.isEmpty)
  }

  @Test func wrongTypeComputedStylesDefaultsToEmptyDict() {
    let dict: [String: Any] = [
      "computedStyles": "not a dictionary",
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.computedStyles.isEmpty)
  }

  @Test func wrongTypeAvailableFontFamiliesDefaultsToEmptyArray() {
    let dict: [String: Any] = [
      "availableFontFamilies": "not an array",
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.availableFontFamilies.isEmpty)
  }

  @Test func availableFontFamiliesIgnoresNonStringValues() {
    let dict: [String: Any] = [
      "availableFontFamilies": ["Inter", 42, "Georgia"],
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.availableFontFamilies == ["Inter", "Georgia"])
  }

  @Test func wrongTypeBoundingRectDefaultsToZeroRect() {
    let dict: [String: Any] = [
      "boundingRect": "not a dictionary",
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.boundingRect == .zero)
  }

  @Test func wrongTypeStringFieldsDefaultToEmptyString() {
    let dict: [String: Any] = [
      "tagName": 42,
      "elementId": true,
      "className": 3.14,
    ]
    let data = ElementInspectorBridge.parseElementData(dict)
    #expect(data.tagName == "")
    #expect(data.elementId == "")
    #expect(data.className == "")
  }

  @Test func eachCallGeneratesUniqueUUID() {
    let a = ElementInspectorBridge.parseElementData([:])
    let b = ElementInspectorBridge.parseElementData([:])
    #expect(a.id != b.id)
  }

  @Test func regularLevelMatchesLegacyCaptureProfile() {
    #expect(ElementInspectorDataLevel.regular.styleKeys == [
      "color",
      "backgroundColor",
      "fontSize",
      "fontWeight",
      "padding",
      "margin",
      "display",
      "borderRadius",
      "width",
      "height",
    ])
    #expect(ElementInspectorDataLevel.regular.textCharacterLimit == 100)
    #expect(ElementInspectorDataLevel.regular.htmlCharacterLimit == 500)
    #expect(!ElementInspectorDataLevel.regular.includesExtendedContext)
  }

  @Test func fullLevelEnablesExpandedCaptureProfile() {
    #expect(ElementInspectorDataLevel.full.styleKeys.contains("opacity"))
    #expect(ElementInspectorDataLevel.full.styleKeys.contains("paddingTop"))
    #expect(ElementInspectorDataLevel.full.styleKeys.contains("boxShadow"))
    #expect(ElementInspectorDataLevel.full.textCharacterLimit == 5000)
    #expect(ElementInspectorDataLevel.full.htmlCharacterLimit == 5000)
    #expect(ElementInspectorDataLevel.full.includesExtendedContext)
  }
}
