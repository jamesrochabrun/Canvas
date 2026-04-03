//
//  ElementSemanticLabel.swift
//  Canvas
//
//  Human-readable semantic label and icon derived from an HTML tag name.
//

import Foundation

/// A semantic label for an HTML element, pairing a human-readable name
/// with an SF Symbol icon for use in inspector badges.
public struct ElementSemanticLabel: Equatable, Sendable {

  /// The human-readable semantic name (e.g., "Heading", "Button", "Link").
  public let label: String

  /// SF Symbol name for the badge icon.
  public let icon: String

  /// Creates a semantic label from a raw HTML tag name.
  public init(tagName: String) {
    let upper = tagName.uppercased()
    (self.label, self.icon) = Self.mapping[upper] ?? ("Element", "rectangle.on.rectangle")
  }

  /// The tint color category for the badge.
  public var badgeColor: BadgeColor {
    switch label {
    case "Heading", "Paragraph", "InlineText", "Blockquote", "Code", "Emphasis", "Strong", "SmallText", "Label":
      return .text
    case "Button", "Link", "Input", "TextArea", "Select", "Form":
      return .interactive
    case "Image", "Video", "Canvas":
      return .media
    case "List", "ListItem", "Table", "TableHead", "TableBody", "TableRow", "TableCell", "TableHeader",
         "DefinitionList", "DefinitionTerm", "DefinitionDetail":
      return .data
    default:
      return .structural
    }
  }

  /// Broad color category for the semantic badge.
  public enum BadgeColor: Sendable, Equatable {
    case text
    case interactive
    case media
    case structural
    case data
  }

  // MARK: - Tag mapping table

  private static let mapping: [String: (String, String)] = [
    // Text
    "H1": ("Heading", "textformat.size.larger"),
    "H2": ("Heading", "textformat.size.larger"),
    "H3": ("Heading", "textformat.size"),
    "H4": ("Heading", "textformat.size"),
    "H5": ("Heading", "textformat.size.smaller"),
    "H6": ("Heading", "textformat.size.smaller"),
    "P": ("Paragraph", "text.alignleft"),
    "SPAN": ("InlineText", "text.cursor"),
    "BLOCKQUOTE": ("Blockquote", "text.quote"),
    "PRE": ("Code", "chevron.left.forwardslash.chevron.right"),
    "CODE": ("Code", "chevron.left.forwardslash.chevron.right"),
    "EM": ("Emphasis", "italic"),
    "STRONG": ("Strong", "bold"),
    "SMALL": ("SmallText", "textformat.size.smaller"),
    "LABEL": ("Label", "tag"),

    // Interactive
    "BUTTON": ("Button", "button.programmable"),
    "A": ("Link", "link"),
    "INPUT": ("Input", "character.cursor.ibeam"),
    "TEXTAREA": ("TextArea", "text.and.command.macwindow"),
    "SELECT": ("Select", "chevron.up.chevron.down"),

    // Media
    "IMG": ("Image", "photo"),
    "SVG": ("Image", "photo"),
    "PICTURE": ("Image", "photo"),
    "VIDEO": ("Video", "play.rectangle"),
    "CANVAS": ("Canvas", "paintbrush"),

    // Structural / Layout
    "NAV": ("Navigation", "sidebar.left"),
    "HEADER": ("Header", "rectangle.topthird.inset.filled"),
    "FOOTER": ("Footer", "rectangle.bottomthird.inset.filled"),
    "SECTION": ("Section", "rectangle.split.3x1"),
    "ARTICLE": ("Article", "doc.text"),
    "ASIDE": ("Sidebar", "sidebar.right"),
    "MAIN": ("Main", "rectangle.center.inset.filled"),
    "DIV": ("Container", "square.dashed"),
    "FIGURE": ("Figure", "photo.on.rectangle"),
    "FIGCAPTION": ("Caption", "text.below.photo"),

    // Data
    "UL": ("List", "list.bullet"),
    "OL": ("List", "list.number"),
    "LI": ("ListItem", "list.bullet.indent"),
    "TABLE": ("Table", "tablecells"),
    "THEAD": ("TableHead", "tablecells"),
    "TBODY": ("TableBody", "tablecells"),
    "TR": ("TableRow", "tablecells"),
    "TD": ("TableCell", "tablecells"),
    "TH": ("TableHeader", "tablecells"),
    "DL": ("DefinitionList", "list.dash"),
    "DT": ("DefinitionTerm", "list.dash"),
    "DD": ("DefinitionDetail", "list.dash"),

    // Form
    "FORM": ("Form", "doc.plaintext"),
    "FIELDSET": ("Fieldset", "rectangle"),
    "LEGEND": ("Legend", "text.badge.star"),
  ]
}
