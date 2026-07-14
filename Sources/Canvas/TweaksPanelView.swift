//
//  TweaksPanelView.swift
//  WebInspector
//
//  Popover content for tweakable props: a describe-a-tweak field with an
//  "Ideas" action, plus native controls for every prop the page declared.
//  Presentation (popover anchoring, sizing) is owned by the host app.
//

import SwiftUI

// MARK: - TweaksPanelView

/// Renders the tweaks popover: a free-form tweak description field, an
/// "Ideas" button, and one native control per declared prop.
public struct TweaksPanelView: View {
  private let state: TweaksState
  private let onSubmitDescription: (String) -> Void
  private let onIdeas: () -> Void
  private let onValueChange: (TweakProp, TweakPropValue) -> Void
  private let onDeleteAll: () -> Void
  private let onReset: () -> Void
  private let onSaveDefaults: () -> Void
  private let agentState: TweaksAgentState
  private let defaultsSaveState: TweaksDefaultsSaveState

  @State private var descriptionText = ""

  public init(
    state: TweaksState,
    agentState: TweaksAgentState = .idle,
    defaultsSaveState: TweaksDefaultsSaveState = .idle,
    onSubmitDescription: @escaping (String) -> Void,
    onIdeas: @escaping () -> Void,
    onValueChange: @escaping (TweakProp, TweakPropValue) -> Void,
    onDeleteAll: @escaping () -> Void,
    onReset: @escaping () -> Void,
    onSaveDefaults: @escaping () -> Void
  ) {
    self.state = state
    self.agentState = agentState
    self.defaultsSaveState = defaultsSaveState
    self.onSubmitDescription = onSubmitDescription
    self.onIdeas = onIdeas
    self.onValueChange = onValueChange
    self.onDeleteAll = onDeleteAll
    self.onReset = onReset
    self.onSaveDefaults = onSaveDefaults
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      describeField
      agentStatus
      if state.hasProps {
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(state.props) { prop in
              controlRow(for: prop)
            }
          }
        }
        .scrollBounceBehavior(.basedOnSize)
        .disabled(agentState == .working || defaultsSaveState.isSaving)
        Divider()
        TweaksPanelFooter(
          agentState: agentState,
          saveState: defaultsSaveState,
          onDeleteAll: onDeleteAll,
          onReset: onReset,
          onSaveDefaults: onSaveDefaults
        )
      } else {
        emptyState
      }
    }
    .padding(14)
  }

  // MARK: - Describe field

  private var describeField: some View {
    HStack(spacing: 8) {
      TextField("Describe a tweak…", text: $descriptionText)
        .textFieldStyle(.plain)
        .onSubmit(submitDescription)
        .disabled(agentState == .working || defaultsSaveState.isSaving)

      Button(action: onIdeas) {
        HStack(spacing: 4) {
          Text("Ideas")
          Image(systemName: "sparkles")
        }
        .font(.callout)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .disabled(agentState == .working || defaultsSaveState.isSaving)
      .help("Ask the agent to invent expressive tweak controls for this design")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(.quaternary, lineWidth: 1)
    )
  }

  private func submitDescription() {
    let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSubmitDescription(trimmed)
    descriptionText = ""
  }

  @ViewBuilder
  private var agentStatus: some View {
    switch agentState {
    case .idle:
      EmptyView()
    case .working:
      Label {
        Text("Updating tweaks…")
      } icon: {
        ProgressView()
          .controlSize(.small)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.circle")
        .font(.caption)
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
    case .conflict:
      Label(
        "The file changed while tweaks were being added. Submit again to use the latest version.",
        systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
      )
      .font(.caption)
      .foregroundStyle(.orange)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "slider.horizontal.3")
        .font(.title3)
        .foregroundStyle(.tertiary)
      Text("No tweakable props yet")
        .font(.callout)
        .foregroundStyle(.secondary)
      Text("Use Ideas to have the agent add expressive controls to this design.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }

  // MARK: - Controls

  @ViewBuilder
  private func controlRow(for prop: TweakProp) -> some View {
    switch prop.type {
    case .slider:
      sliderRow(for: prop)
    case .select:
      labeledRow(for: prop) { selectControl(for: prop) }
    case .color:
      labeledRow(for: prop) { colorControl(for: prop) }
    case .toggle:
      labeledRow(for: prop) { toggleControl(for: prop) }
    case .text:
      textRow(for: prop)
    }
  }

  private func labeledRow(for prop: TweakProp, @ViewBuilder control: () -> some View) -> some View {
    HStack(spacing: 8) {
      Text(prop.label)
        .font(.callout)
      Spacer(minLength: 12)
      control()
    }
  }

  private func sliderRow(for prop: TweakProp) -> some View {
    let range = sliderRange(for: prop)
    let binding = Binding(
      get: { prop.value.doubleValue ?? range.lowerBound },
      set: { newValue in
        let quantizedValue = TweakSliderValueQuantizer.quantize(
          newValue,
          in: range,
          step: prop.step
        )
        onValueChange(prop, .number(quantizedValue))
      }
    )
    return VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(prop.label)
          .font(.callout)
        Spacer()
        Text(sliderValueText(for: prop))
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      TweakSlider(
        value: binding,
        in: range,
        step: prop.step,
        accessibilityLabel: prop.label,
        accessibilityValue: sliderValueText(for: prop)
      )
    }
  }

  private func sliderRange(for prop: TweakProp) -> ClosedRange<Double> {
    let value = prop.value.doubleValue ?? 0
    let lower = prop.minimum ?? Swift.min(0, value)
    let upper = prop.maximum ?? Swift.max(100, value)
    guard upper > lower else { return lower...(lower + 1) }
    return lower...upper
  }

  private func sliderValueText(for prop: TweakProp) -> String {
    let value = prop.value.doubleValue ?? 0
    if value == value.rounded(), (prop.step ?? 1) == (prop.step ?? 1).rounded() {
      return String(Int(value))
    }
    return String(format: "%.1f", value)
  }

  private func selectControl(for prop: TweakProp) -> some View {
    let binding = Binding(
      get: { prop.value.stringValue ?? prop.options.first ?? "" },
      set: { onValueChange(prop, .string($0)) }
    )
    return Picker(prop.label, selection: binding) {
      ForEach(prop.options, id: \.self) { option in
        Text(option).tag(option)
      }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .fixedSize()
    .accessibilityLabel(prop.label)
  }

  private func colorControl(for prop: TweakProp) -> some View {
    let binding = Binding(
      get: { TweakColorHex.color(fromHex: prop.value.stringValue ?? "") ?? .clear },
      set: { newColor in
        guard let hex = TweakColorHex.hexString(from: newColor) else { return }
        onValueChange(prop, .string(hex))
      }
    )
    return ColorPicker(prop.label, selection: binding)
      .labelsHidden()
      .accessibilityLabel(prop.label)
  }

  private func toggleControl(for prop: TweakProp) -> some View {
    let binding = Binding(
      get: { prop.value.boolValue ?? false },
      set: { onValueChange(prop, .boolean($0)) }
    )
    return Toggle(prop.label, isOn: binding)
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.small)
      .accessibilityLabel(prop.label)
  }

  private func textRow(for prop: TweakProp) -> some View {
    let binding = Binding(
      get: { prop.value.stringValue ?? "" },
      set: { onValueChange(prop, .string($0)) }
    )
    return VStack(alignment: .leading, spacing: 4) {
      Text(prop.label)
        .font(.callout)
      TextField(prop.label, text: binding)
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .accessibilityLabel(prop.label)
    }
  }
}
