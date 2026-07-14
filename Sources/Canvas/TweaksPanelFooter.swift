//
//  TweaksPanelFooter.swift
//  WebInspector
//
//  Delete-all, reset, and explicit-default persistence actions for the
//  tweaks panel.
//

import SwiftUI

struct TweaksPanelFooter: View {
  let agentState: TweaksAgentState
  let saveState: TweaksDefaultsSaveState
  let onDeleteAll: () -> Void
  let onReset: () -> Void
  let onSaveDefaults: () -> Void

  @State private var isConfirmingDeleteAll = false

  var body: some View {
    let presentation = TweaksPanelFooterPresentation.resolve(
      agentState: agentState,
      saveState: saveState
    )

    VStack(alignment: .leading, spacing: 8) {
      if let failureMessage = saveState.failureMessage {
        Text(failureMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 12) {
        Button("Delete All Tweaks", systemImage: "trash", role: .destructive) {
          isConfirmingDeleteAll = true
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(presentation.actionsAreDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
        .disabled(presentation.actionsAreDisabled)
        .help("Delete every tweak control and its generated app wiring")
        .confirmationDialog(
          "Delete all tweaks?",
          isPresented: $isConfirmingDeleteAll
        ) {
          Button("Delete All Tweaks", role: .destructive, action: onDeleteAll)
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("This removes every tweak control and its generated app wiring.")
        }

        Spacer()

        Button("Reset", action: onReset)
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .disabled(presentation.actionsAreDisabled)

        Button(action: onSaveDefaults) {
          HStack(spacing: 6) {
            if saveState.isSaving {
              ProgressView()
                .controlSize(.mini)
                .accessibilityHidden(true)
            }

            Text(presentation.saveTitle)
          }
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(.secondary, lineWidth: 1)
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(presentation.actionsAreDisabled)
        .accessibilityLabel(presentation.saveAccessibilityLabel)
      }
    }
  }
}
