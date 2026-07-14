//
//  TweakSliderValueMapper.swift
//  WebInspector
//
//  Pure geometry-to-value logic for TweakSlider: progress rendering, drag
//  position mapping (RTL-aware), and keyboard step adjustment.
//

import SwiftUI

enum TweakSliderValueMapper {

  /// Fraction (0...1) of `value` within `range`, clamped for out-of-range values.
  static func progress(for value: Double, in range: ClosedRange<Double>) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    let fraction = (value - range.lowerBound) / span
    return min(max(fraction, 0), 1)
  }

  /// Maps a pointer x-offset on a track to a prop value.
  ///
  /// Offsets outside the track clamp to the bounds; a compressed (zero-width)
  /// track falls back to the lower bound. Under right-to-left layout the
  /// physical offset is mirrored before mapping. Stepped props quantize to the
  /// declared grid; invalid steps degrade to continuous.
  static func value(
    atOffset offset: Double,
    trackWidth: Double,
    in range: ClosedRange<Double>,
    step: Double?,
    layoutDirection: LayoutDirection
  ) -> Double {
    guard trackWidth > 0 else { return range.lowerBound }
    var fraction = min(max(offset / trackWidth, 0), 1)
    if layoutDirection == .rightToLeft {
      fraction = 1 - fraction
    }
    let rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    return TweakSliderValueQuantizer.quantize(rawValue, in: range, step: step)
  }

  /// Adjusts `value` by one keyboard increment in `direction` (+1 or -1).
  ///
  /// Stepped props move along the grid anchored at the lower bound, snapping
  /// off-grid values to the next grid point in the pressed direction;
  /// continuous props (nil or invalid step) move by 1% of the range. The
  /// result always clamps to the bounds.
  static func adjusted(
    _ value: Double,
    direction: Int,
    in range: ClosedRange<Double>,
    step: Double?
  ) -> Double {
    let clamp = { (candidate: Double) in
      min(max(candidate, range.lowerBound), range.upperBound)
    }
    guard direction != 0 else { return clamp(value) }
    let sign = Double(direction.signum())

    guard let step, step.isFinite, step > 0 else {
      let fallbackStep = (range.upperBound - range.lowerBound) * 0.01
      return clamp(value + sign * fallbackStep)
    }

    let position = (clamp(value) - range.lowerBound) / step
    let nearestIndex = position.rounded()
    let isOnGrid = abs(position - nearestIndex) < 1e-6
    let targetIndex: Double
    if isOnGrid {
      targetIndex = nearestIndex + sign
    } else {
      targetIndex = direction > 0 ? position.rounded(.up) : position.rounded(.down)
    }
    return clamp(range.lowerBound + targetIndex * step)
  }
}
