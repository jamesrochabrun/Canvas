import CoreGraphics
import Testing
@testable import Canvas

@Suite("ElementInspectorPromptBuilder")
struct ElementInspectorPromptBuilderTests {

  @Test func includesOuterHTMLWhenPresent() {
    let element = TestFixtures.makeButton(
      outerHTML: "<button>Click</button>",
      computedStyles: [:]
    )
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("**Element**: <button>Click</button>"))
  }

  @Test func fallsBackToLowercasedTagNameWhenOuterHTMLEmpty() {
    let element = TestFixtures.makeButton(tagName: "BUTTON", outerHTML: "", computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("**Element**: button"))
  }

  @Test func includesCSSSelector() {
    let element = TestFixtures.makeButton(cssSelector: "form > button.primary", computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("**CSS Selector**: form > button.primary"))
  }

  @Test func includesUserInstruction() {
    let element = TestFixtures.makeButton(computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "make it red")
    #expect(prompt.contains("User request: make it red"))
  }

  @Test func includesClosingDirective() {
    let element = TestFixtures.makeButton(computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("Please modify the source code to make this change."))
  }

  @Test func filtersToRelevantStyleKeysOnly() {
    let element = TestFixtures.makeButton(
      computedStyles: [
        "color": "red",
        "cursor": "pointer",
        "pointerEvents": "auto",
      ]
    )
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("color: red"))
    #expect(!prompt.contains("cursor"))
    #expect(!prompt.contains("pointerEvents"))
  }

  @Test func excludesStylesWithEmptyValues() {
    let element = TestFixtures.makeButton(
      computedStyles: ["color": "", "backgroundColor": "blue"]
    )
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(!prompt.contains("  color:"))
    #expect(prompt.contains("  backgroundColor: blue"))
  }

  @Test func omitsComputedStylesSectionWhenNoRelevantStyles() {
    let element = TestFixtures.makeButton(computedStyles: ["font-family": "Arial"])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(!prompt.contains("**Computed Styles**"))
  }

  @Test func includesStylesHeaderWhenStylesExist() {
    let element = TestFixtures.makeButton(computedStyles: ["color": "red"])
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("**Computed Styles**:"))
  }

  @Test func handlesCamelCaseStyleVariants() {
    let element = TestFixtures.makeButton(
      computedStyles: [
        "backgroundColor": "green",
        "fontSize": "18px",
        "borderTopLeftRadius": "4px",
      ]
    )
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "test")
    #expect(prompt.contains("  backgroundColor: green"))
    #expect(prompt.contains("  fontSize: 18px"))
    #expect(prompt.contains("  borderTopLeftRadius: 4px"))
  }

  @Test func correctLineOrdering() {
    let element = TestFixtures.makeButton(
      outerHTML: "<button>OK</button>",
      cssSelector: ".btn",
      computedStyles: ["color": "red"]
    )
    let prompt = ElementInspectorPromptBuilder.buildPrompt(element: element, instruction: "change color")
    let lines = prompt.components(separatedBy: "\n")

    #expect(lines[0] == "I'm looking at a web element in the live preview:")
    #expect(lines[1] == "")
    #expect(lines[2] == "**Element**: <button>OK</button>")
    #expect(lines[3] == "**CSS Selector**: .btn")
    #expect(lines[4] == "**Computed Styles**:")
    #expect(lines[5] == "  color: red")
    #expect(lines[6] == "")
    #expect(lines[7] == "User request: change color")
    #expect(lines[8] == "")
    #expect(lines[9] == "Please modify the source code to make this change.")
  }

  // MARK: - Context Prompt

  @Test func contextPromptIncludesElement() {
    let element = TestFixtures.makeButton(
      outerHTML: "<button>Click</button>",
      cssSelector: ".btn",
      computedStyles: [:]
    )
    let prompt = ElementInspectorPromptBuilder.buildContextPrompt(element: element)
    #expect(prompt.contains("**Element**: <button>Click</button>"))
    #expect(prompt.contains("**CSS Selector**: .btn"))
  }

  @Test func contextPromptOmitsUserRequest() {
    let element = TestFixtures.makeButton(computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildContextPrompt(element: element)
    #expect(!prompt.contains("User request"))
    #expect(!prompt.contains("Please modify the source code"))
  }

  @Test func contextPromptIncludesRelevantStyles() {
    let element = TestFixtures.makeButton(computedStyles: ["color": "red", "font-family": "Arial"])
    let prompt = ElementInspectorPromptBuilder.buildContextPrompt(element: element)
    #expect(prompt.contains("color: red"))
    #expect(!prompt.contains("font-family"))
  }

  @Test func contextPromptFallsBackToTagName() {
    let element = TestFixtures.makeButton(tagName: "DIV", outerHTML: "", computedStyles: [:])
    let prompt = ElementInspectorPromptBuilder.buildContextPrompt(element: element)
    #expect(prompt.contains("**Element**: div"))
  }

  @Test func multiElementPromptIncludesNumberedSections() {
    let elements = [
      TestFixtures.makeButton(
        outerHTML: "<button>Launch</button>",
        cssSelector: ".hero button",
        computedStyles: ["color": "white"]
      ),
      TestFixtures.makeButton(
        tagName: "SECTION",
        outerHTML: "<section class=\"pricing\"></section>",
        cssSelector: ".pricing",
        computedStyles: ["backgroundColor": "black"]
      ),
    ]

    let prompt = ElementInspectorPromptBuilder.buildPrompt(
      elements: elements,
      instruction: "Make these feel like one component"
    )

    #expect(prompt.contains("### Element 1"))
    #expect(prompt.contains("### Element 2"))
    #expect(prompt.contains(".hero button"))
    #expect(prompt.contains(".pricing"))
    #expect(prompt.contains("User request: Make these feel like one component"))
  }

  @Test func multiElementContextPromptIncludesNumberedSections() {
    let elements = [
      TestFixtures.makeButton(
        outerHTML: "<button>Launch</button>",
        cssSelector: ".hero button",
        computedStyles: ["color": "white"]
      ),
      TestFixtures.makeButton(
        tagName: "SECTION",
        outerHTML: "<section class=\"pricing\"></section>",
        cssSelector: ".pricing",
        computedStyles: ["backgroundColor": "black"]
      ),
    ]

    let prompt = ElementInspectorPromptBuilder.buildContextPrompt(elements: elements)

    #expect(prompt.contains("### Element 1"))
    #expect(prompt.contains("### Element 2"))
    #expect(prompt.contains(".hero button"))
    #expect(prompt.contains(".pricing"))
    #expect(!prompt.contains("User request"))
  }

  // MARK: - Crop Prompt

  @Test func cropPromptIncludesRegionDimensions() {
    let rect = CGRect(x: 84, y: 424, width: 430, height: 130)
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: [],
      instruction: "what is this?"
    )
    #expect(prompt.contains("**Region**: 430px \u{00d7} 130px at (84, 424)"))
  }

  @Test func cropPromptWithZeroElementsOmitsElementsSection() {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: [],
      instruction: "describe this"
    )
    #expect(!prompt.contains("**Elements in region**"))
    #expect(prompt.contains("User request: describe this"))
    #expect(prompt.contains("Please modify the source code to make this change."))
  }

  @Test func cropPromptWithElementsIncludesElementsSection() {
    let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
    let elements = [
      TestFixtures.makeButton(outerHTML: "<button>OK</button>", cssSelector: ".btn", computedStyles: [:])
    ]
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: elements,
      instruction: "make it bigger"
    )
    #expect(prompt.contains("**Elements in region** (1):"))
    #expect(prompt.contains("### Element 1"))
    #expect(prompt.contains("<button>OK</button>"))
    #expect(prompt.contains("User request: make it bigger"))
  }

  @Test func cropPromptWithScreenshotPathIncludesScreenshotLine() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: [],
      instruction: "test",
      screenshotPath: "/tmp/AgentHub/crop-screenshots/crop-abc12345-1234567890.png"
    )
    #expect(prompt.contains("**Screenshot**: /tmp/AgentHub/crop-screenshots/crop-abc12345-1234567890.png"))
  }

  @Test func cropPromptWithoutScreenshotPathOmitsScreenshotLine() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: [],
      instruction: "test"
    )
    #expect(!prompt.contains("**Screenshot**"))
  }

  @Test func cropPromptScreenshotAppearsBeforeElements() {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
    let elements = [
      TestFixtures.makeButton(outerHTML: "<p>Hello</p>", cssSelector: "p", computedStyles: [:])
    ]
    let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
      cropRect: rect,
      elements: elements,
      instruction: "change it",
      screenshotPath: "/tmp/shot.png"
    )
    let screenshotIndex = prompt.range(of: "**Screenshot**")!.lowerBound
    let elementsIndex = prompt.range(of: "**Elements in region**")!.lowerBound
    #expect(screenshotIndex < elementsIndex)
  }
}
