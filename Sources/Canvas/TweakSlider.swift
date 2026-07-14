//
//  TweakSlider.swift
//  WebInspector
//
//  Accent-tinted replacement for the stock Slider used in tweaks panel rows:
//  capsule track with a progress fill, hover/drag thumb scaling, keyboard
//  stepping, and a native Slider accessibility representation.
//

import SwiftUI

// MARK: - TweakSlider

/// A branded slider for tweak prop rows.
///
/// Renders a capsule track with an accent-colored progress fill and a ringed
/// thumb. Supports dragging anywhere on the track, arrow-key adjustment by
/// the declared step (or 1% of the range for continuous props), and exposes a
/// native `Slider` to assistive technologies. The accent follows the
/// consuming app's theme by default (`Color.accentColor`) and can be
/// overridden per instance.
public struct TweakSlider: View {
  @Binding private var value: Double
  private let range: ClosedRange<Double>
  private let step: Double?
  private let accentColor: Color
  private let accessibilityLabel: String
  private let accessibilityValue: String

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovering = false
  @State private var isDragging = false
  @FocusState private var isFocused: Bool

  /// Creates a tweak slider.
  ///
  /// - Parameters:
  ///   - value: The current prop value.
  ///   - range: The declared bounds; the upper bound must exceed the lower.
  ///   - step: The declared step. Invalid steps (non-finite or ≤ 0) degrade
  ///     to a continuous slider.
  ///   - accentColor: The primary color for the fill, thumb ring, and focus
  ///     ring. Defaults to the app accent so every consumer's slider matches
  ///     its own theme.
  ///   - accessibilityLabel: The prop label announced by assistive tech.
  ///   - accessibilityValue: The formatted current value announced by
  ///     assistive tech.
  public init(
    value: Binding<Double>,
    in range: ClosedRange<Double>,
    step: Double? = nil,
    accentColor: Color = .accentColor,
    accessibilityLabel: String,
    accessibilityValue: String
  ) {
    precondition(range.upperBound > range.lowerBound, "TweakSlider requires range.upperBound > range.lowerBound")
    self._value = value
    self.range = range
    self.step = step
    self.accentColor = accentColor
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityValue = accessibilityValue
  }

  public var body: some View {
    GeometryReader { proxy in
      track(width: proxy.size.width)
    }
    .frame(height: Metrics.controlHeight)
    .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
    .focusable(isEnabled)
    .focused($isFocused)
    .focusEffectDisabled()
    .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow], action: handleKeyPress)
    .accessibilityRepresentation { accessibilitySlider }
  }

  // MARK: - Track

  private func track(width: CGFloat) -> some View {
    let progress = TweakSliderValueMapper.progress(for: value, in: range)
    return ZStack(alignment: .leading) {
      Capsule()
        .fill(trackColor)
        .frame(height: Metrics.trackHeight)

      Capsule()
        .fill(accentColor)
        .frame(width: fillWidth(progress: progress, trackWidth: width), height: Metrics.trackHeight)

      thumb
        .padding(.leading, thumbOffset(progress: progress, trackWidth: width))
    }
    .frame(maxHeight: .infinity)
    .contentShape(.rect)
    .gesture(dragGesture(trackWidth: width), including: isEnabled ? .all : .none)
  }

  private var thumb: some View {
    Circle()
      .fill(thumbColor)
      .overlay(
        Circle()
          .strokeBorder(accentColor, lineWidth: Metrics.thumbRingWidth)
      )
      .background(
        Circle()
          .stroke(accentColor.opacity(Metrics.focusRingOpacity), lineWidth: Metrics.focusRingWidth)
          .opacity(isFocused ? 1 : 0)
      )
      .frame(width: Metrics.thumbDiameter, height: Metrics.thumbDiameter)
      .scaleEffect(thumbScale)
      .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
      .animation(.easeOut(duration: 0.12), value: thumbScale)
      .onHover { hovering in
        isHovering = hovering && isEnabled
      }
  }

  private var thumbScale: CGFloat {
    if isDragging { return Metrics.dragScale }
    if isHovering { return Metrics.hoverScale }
    return 1
  }

  // MARK: - Colors

  private var trackColor: Color {
    .primary.opacity(colorScheme == .dark ? 0.22 : 0.12)
  }

  private var thumbColor: Color {
    colorScheme == .dark ? Color(white: 0.92) : .white
  }

  // MARK: - Geometry

  private func fillWidth(progress: Double, trackWidth: CGFloat) -> CGFloat {
    max(Metrics.thumbDiameter / 2, progress * trackWidth)
  }

  private func thumbOffset(progress: Double, trackWidth: CGFloat) -> CGFloat {
    let travel = max(0, trackWidth - Metrics.thumbDiameter)
    return progress * travel
  }

  // MARK: - Interaction

  private func dragGesture(trackWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        isDragging = true
        value = TweakSliderValueMapper.value(
          atOffset: gesture.location.x,
          trackWidth: trackWidth,
          in: range,
          step: step,
          layoutDirection: layoutDirection
        )
      }
      .onEnded { _ in
        isDragging = false
      }
  }

  private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
    guard isEnabled else { return .ignored }
    let isRTL = layoutDirection == .rightToLeft
    let direction: Int
    switch press.key {
    case .leftArrow:
      direction = isRTL ? 1 : -1
    case .rightArrow:
      direction = isRTL ? -1 : 1
    case .upArrow:
      direction = 1
    case .downArrow:
      direction = -1
    default:
      return .ignored
    }
    value = TweakSliderValueMapper.adjusted(value, direction: direction, in: range, step: step)
    return .handled
  }

  // MARK: - Accessibility

  @ViewBuilder
  private var accessibilitySlider: some View {
    if let step, step.isFinite, step > 0 {
      Slider(value: $value, in: range, step: step) {
        Text(accessibilityLabel)
      }
      .accessibilityValue(accessibilityValue)
    } else {
      Slider(value: $value, in: range) {
        Text(accessibilityLabel)
      }
      .accessibilityValue(accessibilityValue)
    }
  }

  // MARK: - Metrics

  private enum Metrics {
    static let controlHeight: CGFloat = 20
    static let trackHeight: CGFloat = 4
    static let thumbDiameter: CGFloat = 16
    static let thumbRingWidth: CGFloat = 1.5
    static let focusRingWidth: CGFloat = 3
    static let focusRingOpacity: Double = 0.32
    static let hoverScale: CGFloat = 1.04
    static let dragScale: CGFloat = 1.08
    static let disabledOpacity: Double = 0.45
  }
}
