//
//  WebInspectInputView.swift
//  WebInspector
//
//  Floating input overlay that appears after the user clicks an element
//  in web inspect mode. Shows element context and accepts an instruction.
//

import AppKit
import SwiftUI

/// Compact floating editor shown at the bottom of the web preview after an element is selected.
///
/// Displays a semantic badge, element metadata, and a text field for the user to describe
/// the change they want. Enter submits; Escape dismisses.
public struct WebInspectInputView: View {

  // MARK: Lifecycle

  public init(
    element: ElementInspectorData,
    onSubmit: @escaping (String) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.element = element
    self.onSubmit = onSubmit
    self.onDismiss = onDismiss
  }

  // MARK: Internal

  let element: ElementInspectorData
  let onSubmit: (String) -> Void
  let onDismiss: () -> Void

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      semanticBadgeRow

      if !element.textContent.isEmpty {
        textContentPreview
      }

      inputRow
    }
    .padding(12)
    .frame(maxWidth: 520, alignment: .leading)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: -4)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
    )
    .task(id: element.id) {
      try? await Task.sleep(for: .milliseconds(50))
      isFocused = true
    }
  }

  // MARK: Private

  @State private var text = ""
  @FocusState private var isFocused: Bool

  private var semanticLabel: ElementSemanticLabel {
    ElementSemanticLabel(tagName: element.tagName)
  }

  private var semanticBadgeRow: some View {
    HStack(spacing: 6) {
      HStack(spacing: 4) {
        Image(systemName: semanticLabel.icon)
          .font(.system(size: 10))
        Text(semanticLabel.label)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundColor(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(
        Capsule()
          .fill(badgeColor)
      )

      Text(element.cssSelector)
        .font(.system(.caption2, design: .monospaced))
        .foregroundColor(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer()
    }
  }

  private var textContentPreview: some View {
    Text("\"\(element.textContent)\"")
      .font(.system(size: 11))
      .foregroundColor(Color(NSColor.tertiaryLabelColor))
      .lineLimit(1)
      .truncationMode(.tail)
  }

  private var inputRow: some View {
    HStack(alignment: .bottom, spacing: 8) {
      textEditorView
      sendButton
    }
  }

  private var textEditorView: some View {
    TextField("Describe the change...", text: $text, axis: .vertical)
      .textFieldStyle(.plain)
      .focused($isFocused)
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
            isFocused ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor),
            lineWidth: 1
          )
      )
  }

  private var sendButton: some View {
    Button(action: submitMessage) {
      Image(systemName: "arrow.up")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white)
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .frame(width: 28, height: 28)
    .background(
      Circle()
        .fill(isTextEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
    )
    .contentShape(Circle())
    .disabled(isTextEmpty)
    .help("Send to Claude (Enter)")
  }

  private var badgeColor: Color {
    switch semanticLabel.badgeColor {
    case .text:
      Color.purple.opacity(0.8)
    case .interactive:
      Color.blue.opacity(0.8)
    case .media:
      Color.orange.opacity(0.8)
    case .structural:
      Color.gray.opacity(0.7)
    case .data:
      Color.teal.opacity(0.8)
    }
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

// MARK: - Preview

#Preview {
  WebInspectInputView(
    element: ElementInspectorData(
      id: UUID(),
      tagName: "BUTTON",
      elementId: "",
      className: "primary-btn submit-btn",
      textContent: "Submit",
      outerHTML: "<button class=\"primary-btn submit-btn\">Submit</button>",
      cssSelector: ".form-container > .actions > button.primary-btn",
      computedStyles: [
        "background-color": "#FF385C",
        "color": "#fff",
        "font-size": "16px",
        "padding": "12px 24px",
      ],
      boundingRect: CGRect(x: 100, y: 200, width: 120, height: 44)
    ),
    onSubmit: { _ in },
    onDismiss: {}
  )
  .padding(40)
  .background(Color.gray.opacity(0.2))
}
