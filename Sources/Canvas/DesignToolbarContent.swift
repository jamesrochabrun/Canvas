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
  let isTextContentEditable: Bool
  let onEdit: (DesignEdit) -> Void

  public init(
    values: DesignToolbarValues,
    element: ElementInspectorData,
    isTextContentEditable: Bool = false,
    onEdit: @escaping (DesignEdit) -> Void
  ) {
    self.values = values
    self.element = element
    self.isTextContentEditable = isTextContentEditable
    self.onEdit = onEdit
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if showsTextContentEditor {
        textContentEditor
      }

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
  }

  // MARK: - Text Content

  private var showsTextContentEditor: Bool {
    isTextContentEditable
  }

  private var textContentEditor: some View {
    HStack(spacing: 6) {
      Image(systemName: "text.quote")
        .font(.system(size: Self.iconFontSize, weight: .medium))
        .foregroundStyle(.secondary)

      TextField(
        "Text",
        text: Binding(
          get: { values.textContent },
          set: { newValue in
            guard newValue != values.textContent else { return }
            values.textContent = newValue
            onEdit(DesignEdit(element: element, action: .updateTextContent(newValue)))
          }
        ),
        axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(.system(size: Self.textFieldFontSize))
      .lineLimit(1...3)
      .frame(minWidth: 220, idealWidth: 360, maxWidth: 520)
    }
    .padding(.horizontal, Self.controlHorizontalPadding)
    .padding(.vertical, Self.controlVerticalPadding)
    .background(toolControlBackground)
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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
      ForEach(values.fontFamilyOptions, id: \.self) { family in
        Button(family) {
          values.fontFamily = family
          emitEdit(.fontFamily, value: family)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(displayFontFamily)
          .font(.system(size: Self.smallTextFontSize))
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.controlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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
    .frame(width: Self.colorControlWidth, height: Self.controlHeight)
    .contentShape(Rectangle())
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
          .font(.system(size: Self.iconFontSize, weight: .medium))
          .frame(width: Self.iconButtonSize, height: Self.controlHeight)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())

      Text("\(values.fontSize)")
        .font(.system(size: Self.smallTextFontSize, design: .monospaced))
        .frame(minWidth: Self.valueLabelWidth, minHeight: Self.controlHeight)

      Button {
        values.fontSize += 1
        emitEdit(.fontSize, value: "\(values.fontSize)px")
      } label: {
        Image(systemName: "plus")
          .font(.system(size: Self.iconFontSize, weight: .medium))
          .frame(width: Self.iconButtonSize, height: Self.controlHeight)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
    }
    .foregroundColor(.primary)
    .frame(minHeight: Self.controlHeight)
    .background(toolControlBackground)
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
  }

  // MARK: - Bold / Italic

  private var boldItalicButtons: some View {
    HStack(spacing: 0) {
      Button {
        values.isBold.toggle()
        emitEdit(.fontWeight, value: values.isBold ? "700" : "400")
      } label: {
        Text("B")
          .font(.system(size: Self.buttonTextFontSize, weight: .bold))
          .frame(width: Self.textButtonWidth, height: Self.controlHeight)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
      .foregroundColor(values.isBold ? .accentColor : .primary)

      Button {
        values.isItalic.toggle()
        emitEdit(.fontStyle, value: values.isItalic ? "italic" : "normal")
      } label: {
        Text("I")
          .font(.system(size: Self.buttonTextFontSize, weight: .regular).italic())
          .frame(width: Self.textButtonWidth, height: Self.controlHeight)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
      .foregroundColor(values.isItalic ? .accentColor : .primary)
    }
    .frame(minHeight: Self.controlHeight)
    .background(toolControlBackground)
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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
          .font(.system(size: Self.iconFontSize))
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.compactControlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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
          .font(.system(size: Self.iconFontSize))
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.compactControlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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
      .frame(width: Self.colorControlWidth, height: Self.controlHeight)
      .contentShape(Rectangle())
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
          .font(.system(size: Self.iconFontSize))
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.compactControlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
  }

  // MARK: - Image Controls

  @ViewBuilder
  private var imageControls: some View {
    // Image thumbnail placeholder
    RoundedRectangle(cornerRadius: 4)
      .fill(Color.secondary.opacity(0.3))
      .frame(width: Self.imagePreviewWidth, height: Self.controlHeight)
      .overlay(
        Image(systemName: "photo")
          .font(.system(size: Self.iconFontSize))
          .foregroundColor(.secondary)
      )
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))

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
          .font(.system(size: Self.iconFontSize))
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.compactControlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))

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
          .font(.system(size: Self.iconFontSize))
        Image(systemName: "chevron.down")
          .font(.system(size: Self.chevronFontSize, weight: .bold))
      }
      .foregroundColor(.primary)
      .padding(.horizontal, Self.compactControlHorizontalPadding)
      .padding(.vertical, Self.controlVerticalPadding)
      .frame(minHeight: Self.controlHeight)
      .background(toolControlBackground)
      .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .contentShape(RoundedRectangle(cornerRadius: Self.controlCornerRadius))
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

  private static let spacingPresets = [
    "normal", "-0.5px", "0px", "0.5px", "1px", "1.5px", "2px", "3px",
  ]

  private static let radiusPresets = [
    "0px", "4px", "8px", "12px", "16px", "24px", "9999px",
  ]

  private static let controlHeight: CGFloat = 26
  private static let iconButtonSize: CGFloat = 26
  private static let textButtonWidth: CGFloat = 28
  private static let valueLabelWidth: CGFloat = 30
  private static let colorControlWidth: CGFloat = 30
  private static let imagePreviewWidth: CGFloat = 34
  private static let controlHorizontalPadding: CGFloat = 9
  private static let compactControlHorizontalPadding: CGFloat = 7
  private static let controlVerticalPadding: CGFloat = 7
  private static let controlCornerRadius: CGFloat = 6
  private static let iconFontSize: CGFloat = 12
  private static let chevronFontSize: CGFloat = 8
  private static let smallTextFontSize: CGFloat = 12
  private static let textFieldFontSize: CGFloat = 13
  private static let buttonTextFontSize: CGFloat = 14
}
