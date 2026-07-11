//
//  TweakSliderValueQuantizer.swift
//  WebInspector
//
//  Preserves declared slider steps without asking macOS to draw a tick for
//  every discrete value.
//

import Foundation

enum TweakSliderValueQuantizer {
  static func quantize(
    _ value: Double,
    in range: ClosedRange<Double>,
    step: Double?
  ) -> Double {
    let clampedValue = min(max(value, range.lowerBound), range.upperBound)
    guard let step, step.isFinite, step > 0 else { return clampedValue }

    let stepCount = ((clampedValue - range.lowerBound) / step).rounded()
    let quantizedValue = range.lowerBound + (stepCount * step)
    return min(max(quantizedValue, range.lowerBound), range.upperBound)
  }
}
