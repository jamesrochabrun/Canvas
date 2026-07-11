//
//  TweaksPanelFooterPresentation.swift
//  WebInspector
//
//  Pure presentation rules for the tweaks panel footer actions.
//

struct TweaksPanelFooterPresentation: Equatable {
  let actionsAreDisabled: Bool
  let saveTitle: String
  let saveAccessibilityLabel: String

  static func resolve(
    agentState: TweaksAgentState,
    saveState: TweaksDefaultsSaveState
  ) -> TweaksPanelFooterPresentation {
    let isSaving = saveState.isSaving
    return TweaksPanelFooterPresentation(
      actionsAreDisabled: agentState == .working || isSaving,
      saveTitle: isSaving ? "Saving…" : "Save as defaults",
      saveAccessibilityLabel: isSaving ? "Saving defaults" : "Save as defaults"
    )
  }
}
