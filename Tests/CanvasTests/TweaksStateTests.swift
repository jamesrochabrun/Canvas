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

  @Test func dirtyStateTracksValuesThatDifferFromDefaults() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    #expect(!state.hasUnsavedChanges)

    state.updateValue(name: "warmth", .number(85))
    #expect(state.hasUnsavedChanges)

    state.updateValue(name: "warmth", .number(60))
    #expect(!state.hasUnsavedChanges)
  }

  @Test func resetRestoresDefaultsAndReturnsChangedProps() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    state.updateValue(name: "warmth", .number(85))
    state.updateValue(name: "night", .boolean(true))

    let resetProps = state.resetToDefaults()

    #expect(resetProps.map(\.name) == ["warmth", "night"])
    #expect(resetProps.map(\.value) == [.number(60), .boolean(false)])
    #expect(!state.hasUnsavedChanges)
  }

  @Test func commitPromotesCurrentValuesToDefaults() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    state.updateValue(name: "warmth", .number(85))

    state.commitCurrentValuesAsDefaults()

    #expect(state.props[0].value == .number(85))
    #expect(state.props[0].defaultValue == .number(85))
    #expect(!state.hasUnsavedChanges)

    state.updateValue(name: "warmth", .number(20))
    let resetProps = state.resetToDefaults()
    #expect(resetProps.first?.value == .number(85))
  }

  @Test func clearRemovesAllProps() {
    let state = TweaksState()
    state.updateSchema(makeProps())
    state.clear()
    #expect(!state.hasProps)
  }
}
