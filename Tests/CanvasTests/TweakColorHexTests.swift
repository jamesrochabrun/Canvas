import SwiftUI
import Testing
@testable import Canvas

@Suite("TweakColorHex")
struct TweakColorHexTests {

  @Test func parsesSixDigitHex() throws {
    let color = try #require(TweakColorHex.color(fromHex: "#ff6b35"))
    let hex = try #require(TweakColorHex.hexString(from: color))
    #expect(hex == "#ff6b35")
  }

  @Test func parsesShorthandAndAlphaHex() throws {
    let short = try #require(TweakColorHex.color(fromHex: "#fff"))
    #expect(TweakColorHex.hexString(from: short) == "#ffffff")

    let alpha = try #require(TweakColorHex.color(fromHex: "#00000080"))
    let hex = try #require(TweakColorHex.hexString(from: alpha))
    #expect(hex.hasPrefix("#000000"))
    #expect(hex.count == 9)
  }

  @Test func rejectsInvalidHex() {
    #expect(TweakColorHex.color(fromHex: "") == nil)
    #expect(TweakColorHex.color(fromHex: "#zzzzzz") == nil)
    #expect(TweakColorHex.color(fromHex: "red") == nil)
  }
}
