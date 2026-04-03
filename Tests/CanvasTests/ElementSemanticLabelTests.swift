//
//  ElementSemanticLabelTests.swift
//  CanvasTests
//
//  Tests for ElementSemanticLabel tag-to-label mapping and badge colors.
//

import Testing
@testable import Canvas

@Suite("ElementSemanticLabel")
struct ElementSemanticLabelTests {

  // MARK: - Tag-to-label mapping

  @Suite("Tag-to-label mapping")
  struct MappingTests {

    @Test("Heading tags H1-H6 map to Heading")
    func headingTags() {
      for tag in ["H1", "H2", "H3", "H4", "H5", "H6"] {
        let label = ElementSemanticLabel(tagName: tag)
        #expect(label.label == "Heading", "Expected \(tag) to have label 'Heading'")
      }
    }

    @Test("P maps to Paragraph")
    func paragraphTag() {
      #expect(ElementSemanticLabel(tagName: "P").label == "Paragraph")
      #expect(ElementSemanticLabel(tagName: "P").icon == "text.alignleft")
    }

    @Test("BUTTON maps to Button")
    func buttonTag() {
      #expect(ElementSemanticLabel(tagName: "BUTTON").label == "Button")
      #expect(ElementSemanticLabel(tagName: "BUTTON").icon == "button.programmable")
    }

    @Test("A maps to Link")
    func linkTag() {
      #expect(ElementSemanticLabel(tagName: "A").label == "Link")
      #expect(ElementSemanticLabel(tagName: "A").icon == "link")
    }

    @Test("Image tags map to Image")
    func imageTags() {
      for tag in ["IMG", "SVG", "PICTURE"] {
        let label = ElementSemanticLabel(tagName: tag)
        #expect(label.label == "Image", "Expected \(tag) to have label 'Image'")
        #expect(label.icon == "photo")
      }
    }

    @Test("Container and structural tags")
    func containerTags() {
      #expect(ElementSemanticLabel(tagName: "DIV").label == "Container")
      #expect(ElementSemanticLabel(tagName: "SECTION").label == "Section")
      #expect(ElementSemanticLabel(tagName: "NAV").label == "Navigation")
      #expect(ElementSemanticLabel(tagName: "HEADER").label == "Header")
      #expect(ElementSemanticLabel(tagName: "FOOTER").label == "Footer")
    }

    @Test("List tags")
    func listTags() {
      #expect(ElementSemanticLabel(tagName: "UL").label == "List")
      #expect(ElementSemanticLabel(tagName: "OL").label == "List")
      #expect(ElementSemanticLabel(tagName: "LI").label == "ListItem")
    }

    @Test("Table tags")
    func tableTags() {
      #expect(ElementSemanticLabel(tagName: "TABLE").label == "Table")
      #expect(ElementSemanticLabel(tagName: "TD").label == "TableCell")
      #expect(ElementSemanticLabel(tagName: "TH").label == "TableHeader")
    }

    @Test("Form-related tags")
    func formTags() {
      #expect(ElementSemanticLabel(tagName: "FORM").label == "Form")
      #expect(ElementSemanticLabel(tagName: "INPUT").label == "Input")
      #expect(ElementSemanticLabel(tagName: "SELECT").label == "Select")
    }

    @Test("Unknown tag falls back to Element")
    func unknownTag() {
      let label = ElementSemanticLabel(tagName: "CUSTOMTAG")
      #expect(label.label == "Element")
      #expect(label.icon == "rectangle.on.rectangle")
    }

    @Test("Case insensitive")
    func caseInsensitive() {
      #expect(ElementSemanticLabel(tagName: "h1").label == "Heading")
      #expect(ElementSemanticLabel(tagName: "button").label == "Button")
      #expect(ElementSemanticLabel(tagName: "Div").label == "Container")
      #expect(ElementSemanticLabel(tagName: "img").label == "Image")
    }
  }

  // MARK: - Badge colors

  @Suite("Badge colors")
  struct BadgeColorTests {

    @Test("Text elements get text badge color")
    func textBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "H1").badgeColor == .text)
      #expect(ElementSemanticLabel(tagName: "P").badgeColor == .text)
      #expect(ElementSemanticLabel(tagName: "SPAN").badgeColor == .text)
      #expect(ElementSemanticLabel(tagName: "CODE").badgeColor == .text)
    }

    @Test("Interactive elements get interactive badge color")
    func interactiveBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "BUTTON").badgeColor == .interactive)
      #expect(ElementSemanticLabel(tagName: "A").badgeColor == .interactive)
      #expect(ElementSemanticLabel(tagName: "INPUT").badgeColor == .interactive)
      #expect(ElementSemanticLabel(tagName: "FORM").badgeColor == .interactive)
    }

    @Test("Media elements get media badge color")
    func mediaBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "IMG").badgeColor == .media)
      #expect(ElementSemanticLabel(tagName: "VIDEO").badgeColor == .media)
    }

    @Test("Structural elements get structural badge color")
    func structuralBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "DIV").badgeColor == .structural)
      #expect(ElementSemanticLabel(tagName: "NAV").badgeColor == .structural)
      #expect(ElementSemanticLabel(tagName: "SECTION").badgeColor == .structural)
    }

    @Test("Data elements get data badge color")
    func dataBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "TABLE").badgeColor == .data)
      #expect(ElementSemanticLabel(tagName: "UL").badgeColor == .data)
      #expect(ElementSemanticLabel(tagName: "LI").badgeColor == .data)
    }

    @Test("Unknown elements get structural badge color")
    func unknownBadgeColor() {
      #expect(ElementSemanticLabel(tagName: "CUSTOM").badgeColor == .structural)
    }
  }
}
