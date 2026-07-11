//
//  TweaksPanelFooterPresentationTests.swift
//  CanvasTests
//

import Testing
@testable import Canvas

@Suite("TweaksPanelFooterPresentation")
struct TweaksPanelFooterPresentationTests {
  @Test func idleStateKeepsActionsClearAndAvailable() {
    let presentation = TweaksPanelFooterPresentation.resolve(
      agentState: .idle,
      saveState: .idle
    )

    #expect(!presentation.actionsAreDisabled)
    #expect(presentation.saveTitle == "Save as defaults")
  }

  @Test func activeAgentDisablesActions() {
    let presentation = TweaksPanelFooterPresentation.resolve(
      agentState: .working,
      saveState: .idle
    )

    #expect(presentation.actionsAreDisabled)
  }

  @Test func savingStateShowsProgressCopyAndDisablesActions() {
    let presentation = TweaksPanelFooterPresentation.resolve(
      agentState: .idle,
      saveState: .saving
    )

    #expect(presentation.actionsAreDisabled)
    #expect(presentation.saveTitle == "Saving…")
    #expect(presentation.saveAccessibilityLabel == "Saving defaults")
  }

  @Test func failedStateKeepsDirtyActionsEnabled() {
    let presentation = TweaksPanelFooterPresentation.resolve(
      agentState: .idle,
      saveState: .failed("Could not save")
    )

    #expect(!presentation.actionsAreDisabled)
  }
}
