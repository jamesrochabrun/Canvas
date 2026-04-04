//
//  WebInspectCropInputView.swift
//  Canvas
//
//  Floating input overlay shown after the user draws a crop rectangle
//  in crop inspect mode. Shows region dimensions and accepts an instruction.
//

import AppKit
import SwiftUI

/// Compact floating editor shown at the bottom of the web preview after a crop region is selected.
///
/// Displays an orange "Region" badge, crop dimensions, and a text field for the user to describe
/// the change they want. Enter submits; Escape dismisses.
public struct WebInspectCropInputView: View {

  // MARK: Lifecycle

  public init(
    cropRect: CGRect,
    elementCount: Int = 0,
    onSubmit: @escaping (String) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.cropRect = cropRect
    self.elementCount = elementCount
    self.onSubmit = onSubmit
    self.onDismiss = onDismiss
  }

  // MARK: Internal

  let cropRect: CGRect
  let elementCount: Int
  let onSubmit: (String) -> Void
  let onDismiss: () -> Void

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      badgeRow

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
    .onAppear {
      requestFocus()
    }
    .onDisappear {
      focusTask?.cancel()
    }
  }

  // MARK: Private

  @State private var text = ""
  @State private var focusTask: Task<Void, Never>?
  @FocusState private var isFocused: Bool

  private var badgeRow: some View {
    HStack(spacing: 6) {
      HStack(spacing: 4) {
        Image(systemName: "crop")
          .font(.system(size: 10))
        Text("Region")
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundColor(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(
        Capsule()
          .fill(Color.orange.opacity(0.85))
      )

      Text("\(Int(cropRect.width)) \u{00d7} \(Int(cropRect.height)) px")
        .font(.system(.caption2, design: .monospaced))
        .foregroundColor(.secondary)

      if elementCount > 0 {
        Text("\u{2014} \(elementCount) element\(elementCount == 1 ? "" : "s")")
          .font(.system(.caption2))
          .foregroundColor(.secondary)
      }

      Spacer()
    }
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

  private func requestFocus() {
    focusTask?.cancel()
    focusTask = Task { @MainActor in
      isFocused = false
      await Task.yield()
      guard !Task.isCancelled else { return }
      isFocused = true
    }
  }
}
