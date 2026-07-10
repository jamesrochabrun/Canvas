import Testing
@testable import Canvas

@Suite("TweaksPromptBuilder")
struct TweaksPromptBuilderTests {

  @Test func ideasPromptSubstitutesFileName() {
    let prompt = TweaksPromptBuilder.ideasPrompt(fileName: "Bluey Landing.dc.html")
    #expect(prompt.hasPrefix(
      "Add tweakable controls to Bluey Landing.dc.html (declare with dc_set_props, read via this.props): " +
      "study this design and add a tweaks panel with two or three expressive controls that reshape the feel, " +
      "not single-property pixel-pushing"
    ))
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
    }
  }

  @Test func promptsScopeTheAgentToTheDesignFile() {
    let prompt = TweaksPromptBuilder.ideasPrompt(fileName: "index.html")

    #expect(prompt.contains("only edit the named design file"))
    #expect(prompt.contains("Do not start a dev server"))
  }
}
