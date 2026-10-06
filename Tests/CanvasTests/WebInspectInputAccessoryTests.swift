import CoreGraphics
import Foundation
import Testing
@testable import Canvas

@Suite("WebInspectInputAccessoryContext")
@MainActor
struct WebInspectInputAccessoryTests {

  // MARK: - Context creation

  @Test func inputContextReceivesSelectedElement() {
    let state = ElementInspectState()
    state.activate(mode: .input)
    let button = TestFixtures.makeButton()
    state.selectElement(button)

    let context = WebInspectInputAccessoryContext.forInput(
      state: state,
      draftText: "make it blue",
      deactivateOnSubmit: true
    )

    guard case .element(let element)? = context?.selection else {
      Issue.record("Expected an element selection")
      return
    }
    #expect(element.id == button.id)
    #expect(context?.draftText == "make it blue")
  }

  @Test func inputContextIsNilWithoutSelection() {
    let state = ElementInspectState()
    state.activate(mode: .input)

    let context = WebInspectInputAccessoryContext.forInput(
      state: state,
      draftText: "",
      deactivateOnSubmit: true
    )

    #expect(context == nil)
  }

  @Test func cropContextReceivesRectAndCapturedElements() {
    let state = ElementInspectState()
    state.activate(mode: .crop)
    let rect = CGRect(x: 10, y: 20, width: 300, height: 150)
    let elements = [TestFixtures.makeButton(), TestFixtures.makeMinimalDiv()]
    state.selectCropRect(rect, elements: elements)

    let context = WebInspectInputAccessoryContext.forCrop(
      state: state,
      draftText: "",
      deactivateOnSubmit: true
    )

    guard case .crop(let capturedRect, let capturedElements)? = context?.selection else {
      Issue.record("Expected a crop selection")
      return
    }
    #expect(capturedRect == rect)
    #expect(capturedElements.map(\.id) == elements.map(\.id))
  }

  @Test func cropContextIsNilWithoutCropRect() {
    let state = ElementInspectState()
    state.activate(mode: .crop)

    let context = WebInspectInputAccessoryContext.forCrop(
      state: state,
      draftText: "",
      deactivateOnSubmit: true
    )

    #expect(context == nil)
  }

  // MARK: - Draft text

  @Test func draftTextIsTrimmed() {
    let state = ElementInspectState()
    state.activate(mode: .input)
    state.selectElement(TestFixtures.makeButton())

    let context = WebInspectInputAccessoryContext.forInput(
      state: state,
      draftText: "  align the header \n",
      deactivateOnSubmit: true
    )

    #expect(context?.draftText == "align the header")
  }

  // MARK: - Dismiss

  @Test func inputDismissClearsSelectionAndKeepsInspectActive() {
    let state = ElementInspectState()
    state.activate(mode: .input)
    state.selectElement(TestFixtures.makeButton())

    let context = WebInspectInputAccessoryContext.forInput(
      state: state,
      draftText: "",
      deactivateOnSubmit: false
    )
    context?.dismiss()

    #expect(state.selectedElement == nil)
    #expect(state.isActive)
  }

  @Test func inputDismissDeactivatesInspectMode() {
    let state = ElementInspectState()
    state.activate(mode: .input)
    state.selectElement(TestFixtures.makeButton())

    let context = WebInspectInputAccessoryContext.forInput(
      state: state,
      draftText: "",
      deactivateOnSubmit: true
    )
    context?.dismiss()

    #expect(state.selectedElement == nil)
    #expect(!state.isActive)
  }

  @Test func cropDismissClearsCropRectAndKeepsInspectActive() {
    let state = ElementInspectState()
    state.activate(mode: .crop)
    state.selectCropRect(
      CGRect(x: 0, y: 0, width: 100, height: 100),
      elements: [TestFixtures.makeMinimalDiv()]
    )

    let context = WebInspectInputAccessoryContext.forCrop(
      state: state,
      draftText: "",
      deactivateOnSubmit: false
    )
    context?.dismiss()

    #expect(state.cropRect == nil)
    #expect(state.cropElements.isEmpty)
    #expect(state.isActive)
  }

  @Test func cropDismissDeactivatesInspectMode() {
    let state = ElementInspectState()
    state.activate(mode: .crop)
    state.selectCropRect(CGRect(x: 0, y: 0, width: 100, height: 100))

    let context = WebInspectInputAccessoryContext.forCrop(
      state: state,
      draftText: "",
      deactivateOnSubmit: true
    )
    context?.dismiss()

    #expect(state.cropRect == nil)
    #expect(!state.isActive)
  }
}
