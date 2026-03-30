//
//  DesignToolbarContent.swift
//  Canvas
//
//  Inline design controls for the floating toolbar.
//  Adapts controls based on the selected element's category.
//

import AppKit
import SwiftUI

/// Design mode content for the floating toolbar.
///
/// Shows element-appropriate controls:
/// - Text/Button: font family, color, size, bold/italic, alignment, spacing
/// - Image: border-radius, spacing
/// - Container: background color, border-radius, padding
public struct DesignToolbarContent: View {

  @Bindable var values: DesignToolbarValues
  let element: ElementInspectorData
  let onEdit: (DesignEdit) -> Void

  public init(
    values: DesignToolbarValues,
    element: ElementInspectorData,
    onEdit: @escaping (DesignEdit) -> Void
  ) {
    self.values = values
    self.element = element
    self.onEdit = onEdit
  }

  public var body: some View {
    HStack(spacing: 2) {
      if values.category.supportsTextControls {
        textControls
      }

      if values.category.supportsBackgroundColor {
        backgroundColorControl
      }

      if values.category.supportsLayoutControls {
        layoutControls
      }

      if values.category.supportsImageControls {
        imageControls
      }
    }
  }

  // MARK: - Text Controls

  @ViewBuilder
  private var textControls: some View {
    // Font family
    fontFamilyPicker

    divider

    // Color
    colorControl

    divider

    // Font size stepper
    fontSizeStepper

    divider

    // Bold / Italic
    boldItalicButtons

    divider

    // Alignment
    alignmentPicker

    divider

    // Letter spacing
    spacingControl
  }

  // MARK: - Font Family

  private var fontFamilyPicker: some View {
    Menu {
      ForEach(Self.commonFontFamilies, id: \.self) { family in
        Button(family) {
          values.fontFamily = family
          emitEdit(.fontFamily, value: family)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(displayFontFamily)
          .font(.system(size: 11))
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private var displayFontFamily: String {
    // Show just the first family name, strip quotes
    let first = values.fontFamily.split(separator: ",").first ?? Substring(values.fontFamily)
    return first.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
  }

  // MARK: - Color

  private var colorControl: some View {
    ColorPicker("", selection: Binding(
      get: { Color(nsColor: values.nsColor) },
      set: { newColor in
        values.nsColor = NSColor(newColor)
        emitEdit(.color, value: values.color)
      }
    ))
    .labelsHidden()
    .frame(width: 28, height: 24)
  }

  // MARK: - Font Size

  private var fontSizeStepper: some View {
    HStack(spacing: 0) {
      Button {
        guard values.fontSize > 1 else { return }
        values.fontSize -= 1
        emitEdit(.fontSize, value: "\(values.fontSize)px")
      } label: {
        Image(systemName: "minus")
          .font(.system(size: 10, weight: .medium))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)

      Text("\(values.fontSize)")
        .font(.system(size: 11, design: .monospaced))
        .frame(minWidth: 28)

      Button {
        values.fontSize += 1
        emitEdit(.fontSize, value: "\(values.fontSize)px")
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .medium))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
    }
    .foregroundColor(.primary)
    .background(toolControlBackground)
  }

  // MARK: - Bold / Italic

  private var boldItalicButtons: some View {
    HStack(spacing: 0) {
      Button {
        values.isBold.toggle()
        emitEdit(.fontWeight, value: values.isBold ? "700" : "400")
      } label: {
        Text("B")
          .font(.system(size: 13, weight: .bold))
          .frame(width: 26, height: 24)
      }
      .buttonStyle(.plain)
      .foregroundColor(values.isBold ? .accentColor : .primary)

      Button {
        values.isItalic.toggle()
        emitEdit(.fontStyle, value: values.isItalic ? "italic" : "normal")
      } label: {
        Text("I")
          .font(.system(size: 13, weight: .regular).italic())
          .frame(width: 26, height: 24)
      }
      .buttonStyle(.plain)
      .foregroundColor(values.isItalic ? .accentColor : .primary)
    }
    .background(toolControlBackground)
  }

  // MARK: - Alignment

  private var alignmentPicker: some View {
    Menu {
      ForEach(DesignTextAlignment.allCases, id: \.self) { alignment in
        Button {
          values.textAlign = alignment
          emitEdit(.textAlign, value: alignment.rawValue)
        } label: {
          Label(alignment.rawValue.capitalized, systemImage: alignment.icon)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: values.textAlign.icon)
          .font(.system(size: 12))
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  // MARK: - Spacing

  private var spacingControl: some View {
    Menu {
      Button("Letter Spacing") {}
        .disabled(true)
      ForEach(Self.spacingPresets, id: \.self) { value in
        Button(value) {
          values.letterSpacing = value
          emitEdit(.letterSpacing, value: value)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "arrow.left.and.right")
          .font(.system(size: 11))
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  // MARK: - Background Color

  private var backgroundColorControl: some View {
    Group {
      divider

      ColorPicker("", selection: Binding(
        get: { Color(nsColor: values.nsBackgroundColor) },
        set: { newColor in
          values.nsBackgroundColor = NSColor(newColor)
          emitEdit(.backgroundColor, value: values.backgroundColor)
        }
      ))
      .labelsHidden()
      .frame(width: 28, height: 24)
    }
  }

  // MARK: - Layout Controls

  @ViewBuilder
  private var layoutControls: some View {
    divider

    Menu {
      Button("Border Radius") {}
        .disabled(true)
      ForEach(Self.radiusPresets, id: \.self) { value in
        Button(value) {
          values.borderRadius = value
          emitEdit(.borderRadius, value: value)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "square.bottomhalf.filled")
          .font(.system(size: 11))
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  // MARK: - Image Controls

  @ViewBuilder
  private var imageControls: some View {
    // Image thumbnail placeholder
    RoundedRectangle(cornerRadius: 4)
      .fill(Color.secondary.opacity(0.3))
      .frame(width: 32, height: 24)
      .overlay(
        Image(systemName: "photo")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
      )

    divider

    // Border radius for images
    Menu {
      ForEach(Self.radiusPresets, id: \.self) { value in
        Button(value) {
          values.borderRadius = value
          emitEdit(.borderRadius, value: value)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "square.bottomhalf.filled")
          .font(.system(size: 11))
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()

    divider

    // Spacing control
    Menu {
      Button("Object Fit") {}
        .disabled(true)
      ForEach(["cover", "contain", "fill", "none"], id: \.self) { fit in
        Button(fit) {
          values.objectFit = fit
          emitEdit(.objectFit, value: fit)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "arrow.left.and.right")
          .font(.system(size: 11))
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .background(toolControlBackground)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  // MARK: - Helpers

  private var divider: some View {
    Rectangle()
      .fill(Color(NSColor.separatorColor))
      .frame(width: 1, height: 16)
      .padding(.horizontal, 4)
  }

  private var toolControlBackground: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
  }

  private func emitEdit(_ property: DesignEdit.Property, value: String) {
    onEdit(DesignEdit(
      element: element,
      action: .updateProperty(property, value: value)
    ))
  }

  // MARK: - Presets

  private static let commonFontFamilies = [
    "system-ui",
    "sans-serif",
    "serif",
    "monospace",
    "Inter",
    "Helvetica",
    "Arial",
    "Georgia",
    "Times New Roman",
  ]

  private static let spacingPresets = [
    "normal", "-0.5px", "0px", "0.5px", "1px", "1.5px", "2px", "3px",
  ]

  private static let radiusPresets = [
    "0px", "4px", "8px", "12px", "16px", "24px", "9999px",
  ]
}
