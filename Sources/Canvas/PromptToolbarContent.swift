//
//  PromptToolbarContent.swift
//  Canvas
//
//  Text prompt input extracted from WebInspectInputView.
//  Shows a text field and send button for describing changes.
//

import SwiftUI

/// Prompt mode content for the design toolbar.
///
/// Displays a text field ("Ask for changes") and a send button.
/// Enter submits; Shift+Enter inserts a newline; Escape dismisses.
struct PromptToolbarContent: View {

  @Binding var text: String
  var isFocused: FocusState<Bool>.Binding
  let onSubmit: (String) -> Void
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      textField
      sendButton
    }
  }

  // MARK: Private

  private var textField: some View {
    TextField("Ask for changes", text: $text, axis: .vertical)
      .textFieldStyle(.plain)
      .focused(isFocused)
      .font(.system(size: 13))
      .lineLimit(1...3)
      .padding(.horizontal, 11)
      .padding(.vertical, 8)
      .onKeyPress { key in
        handleKeyPress(key)
      }
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(NSColor.textBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            isFocused.wrappedValue
              ? Color.accentColor.opacity(0.5)
              : Color(NSColor.separatorColor),
            lineWidth: 1
          )
      )
  }

  private var sendButton: some View {
    Button(action: submitMessage) {
      Image(systemName: "arrow.up")
        .font(.system(size: 14))
        .foregroundColor(.white)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(width: 28, height: 28)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isTextEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
    )
    .contentShape(Rectangle())
    .disabled(isTextEmpty)
    .help("Send (Enter)")
  }

  private var isTextEmpty: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func submitMessage() {
    guard !isTextEmpty else { return }
    let instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
    text = ""
    onSubmit(instruction)
  }

  private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
    switch key.key {
    case .return:
      if key.modifiers.contains(.shift) {
        return .ignored
      }
      submitMessage()
      return .handled
    case .escape:
      onDismiss()
      return .handled
    default:
      return .ignored
    }
  }
}
