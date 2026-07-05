//
//  TweakColorHex.swift
//  WebInspector
//
//  Hex-string ↔ Color conversion for tweak color props. All conversion goes
//  through sRGB so persisted hex values stay in range for wide-gamut picks.
//

import SwiftUI

/// Converts between `#rrggbb`/`#rrggbbaa` hex strings and SwiftUI colors.
enum TweakColorHex {

  static func color(fromHex hex: String) -> Color? {
    var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("#") { text.removeFirst() }
    if text.count == 3 {
      text = text.map { "\($0)\($0)" }.joined()
    }
    guard text.count == 6 || text.count == 8,
          let value = UInt64(text, radix: 16) else {
      return nil
    }
    let hasAlpha = text.count == 8
    let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
    let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
    let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
    let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
    return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

  static func hexString(from color: Color) -> String? {
    guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return nil }
    let red = Int((converted.redComponent * 255).rounded())
    let green = Int((converted.greenComponent * 255).rounded())
    let blue = Int((converted.blueComponent * 255).rounded())
    let alpha = Int((converted.alphaComponent * 255).rounded())

    func clamped(_ component: Int) -> Int { min(255, max(0, component)) }

    if alpha < 255 {
      return String(
        format: "#%02x%02x%02x%02x",
        clamped(red), clamped(green), clamped(blue), clamped(alpha)
      )
    }
    return String(format: "#%02x%02x%02x", clamped(red), clamped(green), clamped(blue))
  }
}
