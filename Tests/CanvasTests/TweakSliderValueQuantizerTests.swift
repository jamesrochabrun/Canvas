//
//  TweakSliderValueQuantizerTests.swift
//  CanvasTests
//

import Testing
@testable import Canvas

@Suite("TweakSliderValueQuantizer")
struct TweakSliderValueQuantizerTests {
  @Test("Quantizes relative to the lower bound")
  func quantizesRelativeToLowerBound() {
    let value = TweakSliderValueQuantizer.quantize(14, in: 10...30, step: 5)

    #expect(value == 15)
  }

  @Test("Preserves fractional steps")
  func preservesFractionalSteps() {
    let value = TweakSliderValueQuantizer.quantize(0.26, in: 0...1, step: 0.1)

    #expect(abs(value - 0.3) < 0.000_001)
  }

  @Test("Clamps values to the slider range")
  func clampsValuesToRange() {
    #expect(TweakSliderValueQuantizer.quantize(-10, in: 0...100, step: 1) == 0)
    #expect(TweakSliderValueQuantizer.quantize(110, in: 0...100, step: 1) == 100)
  }

  @Test("Invalid steps keep the continuous value")
  func invalidStepsKeepContinuousValue() {
    #expect(TweakSliderValueQuantizer.quantize(42.5, in: 0...100, step: nil) == 42.5)
    #expect(TweakSliderValueQuantizer.quantize(42.5, in: 0...100, step: 0) == 42.5)
  }
}
