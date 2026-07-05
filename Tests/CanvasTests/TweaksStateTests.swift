import Testing
@testable import Canvas

@Suite("TweaksState")
@MainActor
struct TweaksStateTests {

  private func makeProps() -> [TweakProp] {
    [
      TweakProp(name: "warmth", label: "Warmth", type: .slider, minimum: 0, maximum: 100, value: .number(60)),
      TweakProp(name: "night", label: "Night", type: .toggle, value: .boolean(false)),
    ]
  }

  @Test func updateSchemaReplacesProps() {
    let state = TweaksState()
    #expect(!state.hasProps)
    state.updateSchema(makeProps())
    #expect(state.hasProps)
    #expect(state.props.map(\.name) == ["warmth", "night"])
  }

  @Test func updateValueMutatesMatchingProp() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    state.updateValue(name: "warmth", .number(85))
    #expect(state.props[0].value == .number(85))
    #expect(state.props[0].defaultValue == .number(60))
    state.updateValue(name: "unknown", .number(1))
    #expect(state.props.map(\.value) == [.number(85), .boolean(false)])
  }

  @Test func clearRemovesAllProps() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    state.clear()
    #expect(!state.hasProps)
  }
}
