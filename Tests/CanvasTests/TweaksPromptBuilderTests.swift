import Testing
@testable import Canvas

@Suite("TweaksPromptBuilder")
struct TweaksPromptBuilderTests {

  @Test func ideasPromptSubstitutesFileName() {
    let prompt = TweaksPromptBuilder.ideasPrompt(fileName: "Bluey Landing.dc.html")
    #expect(prompt.hasPrefix(
      "Add additional tweakable controls to Bluey Landing.dc.html " +
      "(declare with dc_set_props, read via this.props): first read the entire file"
    ))
  }

  @Test func ideasPromptInventoriesExistingProps() {
    let props = [
      TweakProp(
        name: "warmth",
        label: "Warmth",
        type: .slider,
        value: .number(60)
      ),
      TweakProp(
        name: "nightMode",
        label: "Night Mode",
        type: .toggle,
        value: .boolean(false)
      ),
    ]

    let prompt = TweaksPromptBuilder.ideasPrompt(fileName: "index.html", existingProps: props)

    #expect(prompt.contains("Existing controls currently reported by the live page"))
    #expect(prompt.contains("- warmth: Warmth [slider]"))
    #expect(prompt.contains("- nightMode: Night Mode [toggle]"))
  }

  @Test func customPromptUsesInstruction() {
    let prompt = TweaksPromptBuilder.customPrompt(
      fileName: "index.html",
      instruction: "make the hero section adjustable between playful and serious"
    )
    #expect(prompt.hasPrefix(
      "Add tweakable controls to index.html (declare with dc_set_props, read via this.props): " +
      "make the hero section adjustable between playful and serious"
    ))
  }

  @Test func bothPromptsIncludeContractReference() {
    for prompt in [
      TweaksPromptBuilder.ideasPrompt(fileName: "a.html"),
      TweaksPromptBuilder.customPrompt(fileName: "a.html", instruction: "x"),
    ] {
      #expect(prompt.contains("Tweakable props contract:"))
      #expect(prompt.contains("Call dc_set_props exactly once"))
      #expect(prompt.contains("dc_on_props_changed = render;"))
      #expect(prompt.contains("\"slider\" | \"select\" | \"color\" | \"toggle\" | \"text\""))
      #expect(prompt.contains("extend its existing object literal in place"))
      #expect(prompt.contains("Avoid duplicates by comparing both names/labels and behavior"))
    }
  }

  @Test func promptsScopeTheAgentToTheDesignFile() {
    let prompt = TweaksPromptBuilder.ideasPrompt(fileName: "index.html")

    #expect(prompt.contains("only edit the named design file"))
    #expect(prompt.contains("Do not start a dev server"))
  }
}
