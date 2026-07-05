//
//  TweakPropsSourceEditor.swift
//  WebInspector
//
//  Pure string-level parsing and splicing of the page's single
//  `dc_set_props({...})` declaration, used to persist updated default
//  values back into the HTML source deterministically. No file I/O.
//

import Foundation

// MARK: - TweakPropsSourceEditorError

public enum TweakPropsSourceEditorError: Error, Equatable {
  case callNotFound
  case multipleCalls
  case malformedArgument
  case propNotFound
  case nonScalarValue
  case postConditionFailed
}

// MARK: - TweakPropsSourceEditor

/// Locates the `dc_set_props` object literal in HTML/JS source, parses the
/// declared props, and splices new scalar default values in place.
///
/// The parser is tolerant of single-quoted strings and bare keys, and skips
/// JS comments, HTML comments, and string literals while scanning. Any prop
/// whose `value` is not a scalar literal is treated as live-only: it parses
/// (so name matching still works) but cannot be persisted.
public enum TweakPropsSourceEditor {

  /// Parses the props declared in the source's `dc_set_props` call.
  ///
  /// Mirrors `TweaksBridge.parseSchema` validation: entries missing a valid
  /// type or scalar value (or selects without options) are dropped.
  public static func parseProps(fromSource source: String) throws -> [TweakProp] {
    let entries = try parseCall(Array(source.utf8)).entries
    return entries.compactMap { entry in
      guard let type = entry.type, let value = entry.value else { return nil }
      if type == .select, entry.options.isEmpty { return nil }
      return TweakProp(
        name: entry.name,
        label: entry.label ?? entry.name,
        type: type,
        minimum: entry.minimum,
        maximum: entry.maximum,
        step: entry.step,
        options: entry.options,
        value: value
      )
    }
  }

  /// All prop names declared in the call, including live-only (non-scalar) ones.
  ///
  /// Use this for schema/file matching: a prop with a computed default still
  /// exists at runtime even though it cannot be persisted.
  public static func parsePropNames(fromSource source: String) throws -> [String] {
    try parseCall(Array(source.utf8)).entries.map(\.name)
  }

  /// Returns the source with the named prop's default value replaced.
  ///
  /// After splicing, the result is re-parsed and verified: same prop names in
  /// the same order, the target prop's parsed value equals `newValue`, and
  /// every other value token is byte-identical. Any violation throws and the
  /// caller keeps the original source.
  public static func applyingValueEdit(
    propName: String,
    newValue: TweakPropValue,
    toSource source: String
  ) throws -> String {
    let bytes = Array(source.utf8)
    let call = try parseCall(bytes)
    guard let entry = call.entries.first(where: { $0.name == propName }) else {
      throw TweakPropsSourceEditorError.propNotFound
    }
    guard let tokenRange = entry.valueTokenRange else {
      throw TweakPropsSourceEditorError.nonScalarValue
    }

    let newToken = serialize(newValue, existingToken: entry.valueToken)
    var newBytes = bytes
    newBytes.replaceSubrange(tokenRange, with: Array(newToken.utf8))
    let newSource = String(decoding: newBytes, as: UTF8.self)

    guard let verified = try? parseCall(Array(newSource.utf8)) else {
      throw TweakPropsSourceEditorError.postConditionFailed
    }
    guard verified.entries.map(\.name) == call.entries.map(\.name) else {
      throw TweakPropsSourceEditorError.postConditionFailed
    }
    for (old, new) in zip(call.entries, verified.entries) {
      if old.name == propName {
        guard let parsed = new.value, valuesMatch(parsed, newValue) else {
          throw TweakPropsSourceEditorError.postConditionFailed
        }
      } else if old.valueToken != new.valueToken {
        throw TweakPropsSourceEditorError.postConditionFailed
      }
    }
    return newSource
  }

  // MARK: - Parsed representation

  struct ParsedEntry {
    var name: String
    var label: String?
    var type: TweakPropType?
    var minimum: Double?
    var maximum: Double?
    var step: Double?
    var options: [String] = []
    /// Byte range of the scalar `value` token; nil when the value is not a scalar literal.
    var valueTokenRange: Range<Int>?
    var valueToken: String = ""
    var value: TweakPropValue?
  }

  struct ParsedCall {
    var entries: [ParsedEntry]
  }

  // MARK: - Call location

  static func parseCall(_ bytes: [UInt8]) throws -> ParsedCall {
    let opens = callOpenParenIndexes(in: bytes)
    guard let open = opens.first else { throw TweakPropsSourceEditorError.callNotFound }
    guard opens.count == 1 else { throw TweakPropsSourceEditorError.multipleCalls }

    var i = open + 1
    skipInsignificant(bytes, &i)
    guard i < bytes.count, bytes[i] == ascii("{") else {
      throw TweakPropsSourceEditorError.malformedArgument
    }
    let objectStart = i
    guard let objectEnd = matchingDelimiter(in: bytes, from: objectStart, open: "{", close: "}") else {
      throw TweakPropsSourceEditorError.malformedArgument
    }
    var afterObject = objectEnd + 1
    skipInsignificant(bytes, &afterObject)
    if afterObject < bytes.count, bytes[afterObject] == ascii(",") {
      afterObject += 1
      skipInsignificant(bytes, &afterObject)
    }
    guard afterObject < bytes.count, bytes[afterObject] == ascii(")") else {
      throw TweakPropsSourceEditorError.malformedArgument
    }

    let entries = try parseTopLevelObject(bytes, objectStart: objectStart, objectEnd: objectEnd)
    return ParsedCall(entries: entries)
  }

  /// Indexes of the `(` byte for every `dc_set_props` call in the source,
  /// skipping comments and string literals. Accepts a bare identifier, an
  /// optional `window.` prefix, and optional-chained calls (`dc_set_props?.(`).
  static func callOpenParenIndexes(in bytes: [UInt8]) -> [Int] {
    let identifier = Array("dc_set_props".utf8)
    var results: [Int] = []
    var i = 0
    let count = bytes.count

    while i < count {
      let byte = bytes[i]

      if byte == ascii("/"), i + 1 < count {
        if bytes[i + 1] == ascii("/") {
          i = skipLineComment(bytes, from: i)
          continue
        }
        if bytes[i + 1] == ascii("*") {
          i = skipBlockComment(bytes, from: i)
          continue
        }
      }
      if byte == ascii("<"), matches(bytes, at: i, sequence: "<!--") {
        i = skipHTMLComment(bytes, from: i)
        continue
      }
      if byte == ascii("\"") || byte == ascii("'") || byte == ascii("`") {
        i = skipStringLiteral(bytes, from: i)
        continue
      }
      if byte == identifier[0], matchesIdentifier(bytes, at: i, identifier: identifier),
         hasValidPrefix(bytes, identifierStart: i) {
        if let paren = openParenIndex(bytes, afterIdentifierEnd: i + identifier.count) {
          results.append(paren)
          i = paren + 1
          continue
        }
        i += identifier.count
        continue
      }
      i += 1
    }
    return results
  }

  private static func matchesIdentifier(_ bytes: [UInt8], at index: Int, identifier: [UInt8]) -> Bool {
    guard index + identifier.count <= bytes.count else { return false }
    for (offset, byte) in identifier.enumerated() where bytes[index + offset] != byte {
      return false
    }
    // Reject longer identifiers like dc_set_props2.
    let end = index + identifier.count
    if end < bytes.count, isIdentifierByte(bytes[end]) { return false }
    return true
  }

  /// The identifier must not be a property access, except `window.dc_set_props`.
  private static func hasValidPrefix(_ bytes: [UInt8], identifierStart: Int) -> Bool {
    guard identifierStart > 0 else { return true }
    let previous = bytes[identifierStart - 1]
    if isIdentifierByte(previous) { return false }
    guard previous == ascii(".") else { return true }

    var i = identifierStart - 2
    while i >= 0, isWhitespace(bytes[i]) { i -= 1 }
    let identifierEnd = i
    while i >= 0, isIdentifierByte(bytes[i]) { i -= 1 }
    guard i < identifierEnd else { return false }
    let owner = String(decoding: bytes[(i + 1)...identifierEnd], as: UTF8.self)
    guard owner == "window" else { return false }
    return i < 0 || (bytes[i] != ascii(".") && !isIdentifierByte(bytes[i]))
  }

  private static func openParenIndex(_ bytes: [UInt8], afterIdentifierEnd end: Int) -> Int? {
    var i = end
    skipInsignificant(bytes, &i)
    if i + 1 < bytes.count, bytes[i] == ascii("?"), bytes[i + 1] == ascii(".") {
      i += 2
      skipInsignificant(bytes, &i)
    }
    guard i < bytes.count, bytes[i] == ascii("(") else { return nil }
    return i
  }

  // MARK: - Object parsing

  private static func parseTopLevelObject(
    _ bytes: [UInt8],
    objectStart: Int,
    objectEnd: Int
  ) throws -> [ParsedEntry] {
    var entries: [ParsedEntry] = []
    var i = objectStart + 1

    while true {
      skipInsignificant(bytes, &i)
      guard i < objectEnd else { throw TweakPropsSourceEditorError.malformedArgument }
      if bytes[i] == ascii("}") { break }

      guard let (key, keyEnd) = parseKey(bytes, at: i) else {
        throw TweakPropsSourceEditorError.malformedArgument
      }
      i = keyEnd
      skipInsignificant(bytes, &i)
      guard i < objectEnd, bytes[i] == ascii(":") else {
        throw TweakPropsSourceEditorError.malformedArgument
      }
      i += 1
      skipInsignificant(bytes, &i)
      guard i < objectEnd else { throw TweakPropsSourceEditorError.malformedArgument }

      if bytes[i] == ascii("{") {
        guard let nestedEnd = matchingDelimiter(in: bytes, from: i, open: "{", close: "}") else {
          throw TweakPropsSourceEditorError.malformedArgument
        }
        let entry = parsePropObject(bytes, name: key, objectStart: i, objectEnd: nestedEnd)
        entries.append(entry)
        i = nestedEnd + 1
      } else {
        guard let end = skipValue(bytes, at: i) else {
          throw TweakPropsSourceEditorError.malformedArgument
        }
        i = end
      }

      skipInsignificant(bytes, &i)
      guard i < bytes.count else { throw TweakPropsSourceEditorError.malformedArgument }
      if bytes[i] == ascii(",") {
        i += 1
        continue
      }
      if bytes[i] == ascii("}") { break }
      throw TweakPropsSourceEditorError.malformedArgument
    }
    return entries
  }

  private static func parsePropObject(
    _ bytes: [UInt8],
    name: String,
    objectStart: Int,
    objectEnd: Int
  ) -> ParsedEntry {
    var entry = ParsedEntry(name: name)
    var i = objectStart + 1

    while true {
      skipInsignificant(bytes, &i)
      guard i < objectEnd else { return entry }
      if bytes[i] == ascii("}") { return entry }

      guard let (key, keyEnd) = parseKey(bytes, at: i) else { return entry }
      i = keyEnd
      skipInsignificant(bytes, &i)
      guard i < objectEnd, bytes[i] == ascii(":") else { return entry }
      i += 1
      skipInsignificant(bytes, &i)
      guard i < objectEnd else { return entry }

      switch key {
      case "label":
        if let (decoded, _, end) = parseStringLiteral(bytes, at: i) {
          entry.label = decoded
          i = end
        } else if let end = skipValue(bytes, at: i) {
          i = end
        } else {
          return entry
        }
      case "type":
        if let (decoded, _, end) = parseStringLiteral(bytes, at: i) {
          entry.type = TweakPropType(rawValue: decoded)
          i = end
        } else if let end = skipValue(bytes, at: i) {
          i = end
        } else {
          return entry
        }
      case "value":
        if let scalar = parseScalar(bytes, at: i) {
          entry.value = scalar.value
          entry.valueToken = scalar.token
          entry.valueTokenRange = scalar.value == nil ? nil : scalar.range
          i = scalar.range.upperBound
        } else if let end = skipValue(bytes, at: i) {
          entry.valueToken = String(decoding: bytes[i..<end], as: UTF8.self)
          i = end
        } else {
          return entry
        }
      case "min", "max", "step":
        if let (token, end) = parseNumberToken(bytes, at: i), let number = Double(token) {
          switch key {
          case "min": entry.minimum = number
          case "max": entry.maximum = number
          default: entry.step = number
          }
          i = end
        } else if let end = skipValue(bytes, at: i) {
          i = end
        } else {
          return entry
        }
      case "options":
        if let (strings, end) = parseStringArray(bytes, at: i) {
          entry.options = strings
          i = end
        } else if let end = skipValue(bytes, at: i) {
          i = end
        } else {
          return entry
        }
      default:
        guard let end = skipValue(bytes, at: i) else { return entry }
        i = end
      }

      skipInsignificant(bytes, &i)
      guard i < bytes.count else { return entry }
      if bytes[i] == ascii(",") {
        i += 1
        continue
      }
      if bytes[i] == ascii("}") { return entry }
      return entry
    }
  }

  // MARK: - Token parsing

  private static func parseKey(_ bytes: [UInt8], at index: Int) -> (key: String, end: Int)? {
    if let (decoded, _, end) = parseStringLiteral(bytes, at: index) {
      return (decoded, end)
    }
    guard index < bytes.count, isIdentifierStartByte(bytes[index]) else { return nil }
    var i = index
    while i < bytes.count, isIdentifierByte(bytes[i]) { i += 1 }
    return (String(decoding: bytes[index..<i], as: UTF8.self), i)
  }

  /// Parses a scalar literal. `value` is nil for recognizable-but-non-scalar
  /// tokens (identifiers, null); returns nil entirely when the token is a
  /// composite (object/array) the caller should skip.
  private static func parseScalar(
    _ bytes: [UInt8],
    at index: Int
  ) -> (token: String, range: Range<Int>, value: TweakPropValue?)? {
    guard index < bytes.count else { return nil }
    if let (decoded, raw, end) = parseStringLiteral(bytes, at: index) {
      return (raw, index..<end, .string(decoded))
    }
    if let (token, end) = parseNumberToken(bytes, at: index), let number = Double(token) {
      return (token, index..<end, .number(number))
    }
    if isIdentifierStartByte(bytes[index]) {
      var i = index
      while i < bytes.count, isIdentifierByte(bytes[i]) { i += 1 }
      let token = String(decoding: bytes[index..<i], as: UTF8.self)
      switch token {
      case "true": return (token, index..<i, .boolean(true))
      case "false": return (token, index..<i, .boolean(false))
      default: return (token, index..<i, nil)
      }
    }
    return nil
  }

  /// Decodes a string literal, returning both the decoded text and the raw
  /// token (including quotes). Handles \\, \", \', \n, \r, \t, \/, \uXXXX.
  private static func parseStringLiteral(
    _ bytes: [UInt8],
    at index: Int
  ) -> (decoded: String, raw: String, end: Int)? {
    guard index < bytes.count else { return nil }
    let quote = bytes[index]
    guard quote == ascii("\"") || quote == ascii("'") else { return nil }

    var decoded: [UInt8] = []
    var i = index + 1
    while i < bytes.count {
      let byte = bytes[i]
      if byte == ascii("\\"), i + 1 < bytes.count {
        let escaped = bytes[i + 1]
        switch escaped {
        case ascii("n"): decoded.append(ascii("\n"))
        case ascii("r"): decoded.append(ascii("\r"))
        case ascii("t"): decoded.append(ascii("\t"))
        case ascii("u")
          where i + 5 < bytes.count:
          let hex = String(decoding: bytes[(i + 2)...(i + 5)], as: UTF8.self)
          if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
            decoded.append(contentsOf: Array(String(scalar).utf8))
            i += 6
            continue
          }
          decoded.append(escaped)
        default:
          decoded.append(escaped)
        }
        i += 2
        continue
      }
      if byte == quote {
        let raw = String(decoding: bytes[index...(i)], as: UTF8.self)
        return (String(decoding: decoded, as: UTF8.self), raw, i + 1)
      }
      decoded.append(byte)
      i += 1
    }
    return nil
  }

  private static func parseNumberToken(_ bytes: [UInt8], at index: Int) -> (token: String, end: Int)? {
    var i = index
    guard i < bytes.count else { return nil }
    if bytes[i] == ascii("-") || bytes[i] == ascii("+") { i += 1 }
    let digitsStart = i
    while i < bytes.count, isNumberBodyByte(bytes[i]) { i += 1 }
    guard i > digitsStart else { return nil }
    let token = String(decoding: bytes[index..<i], as: UTF8.self)
    guard Double(token) != nil else { return nil }
    return (token, i)
  }

  private static func parseStringArray(
    _ bytes: [UInt8],
    at index: Int
  ) -> (strings: [String], end: Int)? {
    guard index < bytes.count, bytes[index] == ascii("[") else { return nil }
    guard let close = matchingDelimiter(in: bytes, from: index, open: "[", close: "]") else { return nil }
    var strings: [String] = []
    var i = index + 1
    while i < close {
      skipInsignificant(bytes, &i)
      if i >= close { break }
      if let (decoded, _, end) = parseStringLiteral(bytes, at: i) {
        strings.append(decoded)
        i = end
      } else if let end = skipValue(bytes, at: i) {
        i = end
      } else {
        return nil
      }
      skipInsignificant(bytes, &i)
      if i < close, bytes[i] == ascii(",") { i += 1 }
    }
    return (strings, close + 1)
  }

  /// Skips any value (object, array, string, or scalar run) and returns the
  /// index just past it.
  private static func skipValue(_ bytes: [UInt8], at index: Int) -> Int? {
    guard index < bytes.count else { return nil }
    let byte = bytes[index]
    if byte == ascii("{") {
      return matchingDelimiter(in: bytes, from: index, open: "{", close: "}").map { $0 + 1 }
    }
    if byte == ascii("[") {
      return matchingDelimiter(in: bytes, from: index, open: "[", close: "]").map { $0 + 1 }
    }
    if byte == ascii("\"") || byte == ascii("'") || byte == ascii("`") {
      let end = skipStringLiteral(bytes, from: index)
      return end > index ? end : nil
    }
    var i = index
    while i < bytes.count {
      let b = bytes[i]
      if b == ascii(",") || b == ascii("}") || b == ascii("]") { break }
      i += 1
    }
    return i > index ? i : nil
  }

  // MARK: - Delimiter and skip helpers

  /// Index of the delimiter closing the one at `from`, skipping comments and strings.
  static func matchingDelimiter(
    in bytes: [UInt8],
    from: Int,
    open: Character,
    close: Character
  ) -> Int? {
    let openByte = open.asciiValue!
    let closeByte = close.asciiValue!
    var depth = 0
    var i = from
    while i < bytes.count {
      let byte = bytes[i]
      if byte == ascii("/"), i + 1 < bytes.count {
        if bytes[i + 1] == ascii("/") {
          i = skipLineComment(bytes, from: i)
          continue
        }
        if bytes[i + 1] == ascii("*") {
          i = skipBlockComment(bytes, from: i)
          continue
        }
      }
      if byte == ascii("\"") || byte == ascii("'") || byte == ascii("`") {
        i = skipStringLiteral(bytes, from: i)
        continue
      }
      if byte == openByte {
        depth += 1
      } else if byte == closeByte {
        depth -= 1
        if depth == 0 { return i }
      }
      i += 1
    }
    return nil
  }

  private static func skipInsignificant(_ bytes: [UInt8], _ i: inout Int) {
    while i < bytes.count {
      let byte = bytes[i]
      if isWhitespace(byte) {
        i += 1
        continue
      }
      if byte == ascii("/"), i + 1 < bytes.count {
        if bytes[i + 1] == ascii("/") {
          i = skipLineComment(bytes, from: i)
          continue
        }
        if bytes[i + 1] == ascii("*") {
          i = skipBlockComment(bytes, from: i)
          continue
        }
      }
      break
    }
  }

  private static func skipLineComment(_ bytes: [UInt8], from index: Int) -> Int {
    var i = index + 2
    while i < bytes.count, bytes[i] != ascii("\n") { i += 1 }
    return i
  }

  private static func skipBlockComment(_ bytes: [UInt8], from index: Int) -> Int {
    var i = index + 2
    while i + 1 < bytes.count {
      if bytes[i] == ascii("*"), bytes[i + 1] == ascii("/") { return i + 2 }
      i += 1
    }
    return bytes.count
  }

  private static func skipHTMLComment(_ bytes: [UInt8], from index: Int) -> Int {
    var i = index + 4
    while i + 2 < bytes.count {
      if bytes[i] == ascii("-"), bytes[i + 1] == ascii("-"), bytes[i + 2] == ascii(">") {
        return i + 3
      }
      i += 1
    }
    return bytes.count
  }

  /// Skips a string literal including its quotes; returns the index past the
  /// closing quote (or end of input if unterminated).
  private static func skipStringLiteral(_ bytes: [UInt8], from index: Int) -> Int {
    let quote = bytes[index]
    var i = index + 1
    while i < bytes.count {
      let byte = bytes[i]
      if byte == ascii("\\") {
        i += 2
        continue
      }
      if byte == quote { return i + 1 }
      // Unescaped newline ends a normal (non-template) string; treat as unterminated.
      if byte == ascii("\n"), quote != ascii("`") { return i }
      i += 1
    }
    return bytes.count
  }

  private static func matches(_ bytes: [UInt8], at index: Int, sequence: String) -> Bool {
    let expected = Array(sequence.utf8)
    guard index + expected.count <= bytes.count else { return false }
    for (offset, byte) in expected.enumerated() where bytes[index + offset] != byte {
      return false
    }
    return true
  }

  // MARK: - Serialization

  private static func serialize(_ value: TweakPropValue, existingToken: String) -> String {
    switch value {
    case .number(let number):
      if number == number.rounded(), abs(number) < 1e15 {
        return String(Int64(number))
      }
      return "\(number)"
    case .string(let string):
      let quote: Character = existingToken.first == "'" ? "'" : "\""
      var escaped = string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
      escaped = escaped.replacingOccurrences(of: String(quote), with: "\\\(quote)")
      return "\(quote)\(escaped)\(quote)"
    case .boolean(let flag):
      return flag ? "true" : "false"
    }
  }

  private static func valuesMatch(_ lhs: TweakPropValue, _ rhs: TweakPropValue) -> Bool {
    switch (lhs, rhs) {
    case (.number(let l), .number(let r)):
      return abs(l - r) <= 1e-9 * max(1, abs(l), abs(r))
    default:
      return lhs == rhs
    }
  }

  // MARK: - Byte classification

  private static func ascii(_ character: Character) -> UInt8 {
    character.asciiValue!
  }

  private static func isWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
  }

  private static func isIdentifierStartByte(_ byte: UInt8) -> Bool {
    (byte >= ascii("a") && byte <= ascii("z"))
      || (byte >= ascii("A") && byte <= ascii("Z"))
      || byte == ascii("_") || byte == ascii("$")
  }

  private static func isIdentifierByte(_ byte: UInt8) -> Bool {
    isIdentifierStartByte(byte) || (byte >= ascii("0") && byte <= ascii("9"))
  }

  private static func isNumberBodyByte(_ byte: UInt8) -> Bool {
    (byte >= ascii("0") && byte <= ascii("9"))
      || byte == ascii(".") || byte == ascii("e") || byte == ascii("E")
      || byte == ascii("-") || byte == ascii("+")
  }
}
