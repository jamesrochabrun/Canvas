//
//  TweakSliderValueMapperTests.swift
//  CanvasTests
//

import SwiftUI
import Testing
@testable import Canvas

@Suite("TweakSliderValueMapper")
struct TweakSliderValueMapperTests {

  // MARK: - Progress

  @Test("Maps progress within offset ranges")
  func mapsProgressWithinOffsetRanges() {
    #expect(TweakSliderValueMapper.progress(for: 20, in: 10...30) == 0.5)
    #expect(TweakSliderValueMapper.progress(for: 10, in: 10...30) == 0)
    #expect(TweakSliderValueMapper.progress(for: 30, in: 10...30) == 1)
  }

  @Test("Clamps progress for values outside the range")
  func clampsProgressOutsideRange() {
    #expect(TweakSliderValueMapper.progress(for: 5, in: 10...30) == 0)
    #expect(TweakSliderValueMapper.progress(for: 35, in: 10...30) == 1)
  }

  // MARK: - Drag mapping

  @Test("Maps and clamps LTR drag offsets")
  func mapsAndClampsLeftToRightDragOffsets() {
    #expect(
      TweakSliderValueMapper.value(
        atOffset: 50, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .leftToRight
      ) == 50
    )
    #expect(
      TweakSliderValueMapper.value(
        atOffset: -20, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .leftToRight
      ) == 0
    )
    #expect(
      TweakSliderValueMapper.value(
        atOffset: 140, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .leftToRight
      ) == 100
    )
  }

  @Test("Mirrors and clamps RTL drag offsets")
  func mirrorsAndClampsRightToLeftDragOffsets() {
    #expect(
      TweakSliderValueMapper.value(
        atOffset: 25, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .rightToLeft
      ) == 75
    )
    #expect(
      TweakSliderValueMapper.value(
        atOffset: -20, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .rightToLeft
      ) == 100
    )
    #expect(
      TweakSliderValueMapper.value(
        atOffset: 140, trackWidth: 100, in: 0...100, step: nil, layoutDirection: .rightToLeft
      ) == 0
    )
  }

  @Test("Snaps dragged values to the step grid anchored at the lower bound")
  func snapsDraggedValuesToStepGrid() {
    let value = TweakSliderValueMapper.value(
      atOffset: 22, trackWidth: 100, in: 10...30, step: 5, layoutDirection: .leftToRight
    )
    // 22% of the 10...30 span is 14.4, which snaps to 15 on the 10-anchored grid.
    #expect(value == 15)
  }

  @Test("Compressed track falls back to the lower bound")
  func compressedTrackFallsBackToLowerBound() {
    #expect(
      TweakSliderValueMapper.value(
        atOffset: 50, trackWidth: 0, in: 10...30, step: nil, layoutDirection: .leftToRight
      ) == 10
    )
  }

  // MARK: - Keyboard adjustment

  @Test("Adjusts by the declared step or a 1% fallback")
  func adjustsByDeclaredStepOrOnePercentFallback() {
    #expect(TweakSliderValueMapper.adjusted(50, direction: 1, in: 0...100, step: 5) == 55)
    #expect(TweakSliderValueMapper.adjusted(50, direction: -1, in: 0...100, step: 5) == 45)
    // Continuous props (nil or invalid step) move by 1% of the range span.
    #expect(TweakSliderValueMapper.adjusted(50, direction: 1, in: 0...100, step: nil) == 51)
    #expect(TweakSliderValueMapper.adjusted(50, direction: -1, in: 0...100, step: 0) == 49)
  }

  @Test("Stepped adjustment snaps off-grid values and clamps at the bounds")
  func steppedAdjustmentSnapsOffGridValuesAndClamps() {
    // Off-grid values move to the next grid point in the pressed direction.
    #expect(TweakSliderValueMapper.adjusted(14, direction: 1, in: 10...30, step: 5) == 15)
    #expect(TweakSliderValueMapper.adjusted(14, direction: -1, in: 10...30, step: 5) == 10)
    // Boundary presses clamp instead of overshooting.
    #expect(TweakSliderValueMapper.adjusted(30, direction: 1, in: 10...30, step: 5) == 30)
    #expect(TweakSliderValueMapper.adjusted(10, direction: -1, in: 10...30, step: 5) == 10)
  }
}
