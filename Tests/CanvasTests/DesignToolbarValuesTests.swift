//
//  DesignToolbarValuesTests.swift
//  Canvas
//

import CoreGraphics
import Testing

@testable import Canvas

@Suite("DesignToolbarValues")
struct DesignToolbarValuesTests {

  // MARK: - ElementCategory

  @Suite("ElementCategory classification")
  struct ElementCategoryTests {

    @Test("Text elements")
    func textElements() {
      let textTags = ["H1", "H2", "H3", "H4", "H5", "H6", "P", "SPAN", "A", "LABEL", "LI", "EM", "STRONG"]
      for tag in textTags {
        #expect(ElementCategory(tagName: tag) == .text, "Expected \(tag) to be .text")
      }
    }

    @Test("Case insensitive")
    func caseInsensitive() {
      #expect(ElementCategory(tagName: "h1") == .text)
      #expect(ElementCategory(tagName: "Div") == .container)
      #expect(ElementCategory(tagName: "BUTTON") == .button)
      #expect(ElementCategory(tagName: "img") == .image)
    }

    @Test("Button elements")
    func buttonElements() {
      #expect(ElementCategory(tagName: "BUTTON") == .button)
      #expect(ElementCategory(tagName: "INPUT") == .button)
    }

    @Test("Image elements")
    func imageElements() {
      let imageTags = ["IMG", "SVG", "PICTURE", "VIDEO", "CANVAS"]
      for tag in imageTags {
        #expect(ElementCategory(tagName: tag) == .image, "Expected \(tag) to be .image")
      }
    }

    @Test("Container elements")
    func containerElements() {
      let containerTags = ["DIV", "SECTION", "ARTICLE", "NAV", "HEADER", "FOOTER", "MAIN", "ASIDE", "FORM", "UL", "OL"]
      for tag in containerTags {
        #expect(ElementCategory(tagName: tag) == .container, "Expected \(tag) to be .container")
      }
    }

    @Test("Category capabilities")
    func capabilities() {
      #expect(ElementCategory.text.supportsTextControls)
      #expect(ElementCategory.button.supportsTextControls)
      #expect(!ElementCategory.image.supportsTextControls)
      #expect(!ElementCategory.container.supportsTextControls)

      #expect(!ElementCategory.text.supportsBackgroundColor)
      #expect(ElementCategory.button.supportsBackgroundColor)
      #expect(ElementCategory.container.supportsBackgroundColor)

      #expect(ElementCategory.image.supportsImageControls)
      #expect(!ElementCategory.text.supportsImageControls)
    }
  }

  // MARK: - CSS Parsing

  @Suite("CSS value parsing")
  struct CSSParsingTests {

    @Test("Parse pixel value")
    func parsePixelValue() {
      #expect(CSSParser.parsePixelValue("16px") == 16)
      #expect(CSSParser.parsePixelValue("72px") == 72)
      #expect(CSSParser.parsePixelValue("14.5px") == 14)
      #expect(CSSParser.parsePixelValue("0px") == 0)
    }

    @Test("Bold weight detection")
    func isBoldWeight() {
      #expect(CSSParser.isBoldWeight("bold"))
      #expect(CSSParser.isBoldWeight("bolder"))
      #expect(CSSParser.isBoldWeight("700"))
      #expect(CSSParser.isBoldWeight("600"))
      #expect(CSSParser.isBoldWeight("900"))
      #expect(!CSSParser.isBoldWeight("400"))
      #expect(!CSSParser.isBoldWeight("normal"))
      #expect(!CSSParser.isBoldWeight("300"))
    }

    @Test("Style value lookup with fallback keys")
    func styleValueLookup() {
      let styles = ["fontSize": "16px", "font-family": "Arial"]

      #expect(CSSParser.styleValue(styles, ["fontSize", "font-size"]) == "16px")
      #expect(CSSParser.styleValue(styles, ["fontFamily", "font-family"]) == "Arial")
      #expect(CSSParser.styleValue(styles, ["missing"]) == nil)
    }

    @Test("Empty values are skipped")
    func emptyValuesSkipped() {
      let styles = ["fontSize": "", "font-size": "14px"]
      #expect(CSSParser.styleValue(styles, ["fontSize", "font-size"]) == "14px")
    }
  }

  // MARK: - Init from element

  @Suite("Init from ElementInspectorData")
  struct InitTests {

    @Test("Parses text element styles")
    @MainActor
    func textElement() {
      let element = ElementInspectorData(
        tagName: "H1",
        elementId: "",
        className: "title",
        textContent: "Hello World",
        outerHTML: "<h1>Hello World</h1>",
        cssSelector: "h1.title",
        computedStyles: [
          "fontFamily": "Inter, sans-serif",
          "color": "rgb(255, 255, 255)",
          "fontSize": "48px",
          "fontWeight": "700",
          "fontStyle": "normal",
          "textAlign": "center",
          "letterSpacing": "0.5px",
          "lineHeight": "56px",
        ],
        boundingRect: CGRect(x: 0, y: 0, width: 400, height: 56)
      )

      let values = DesignToolbarValues(element: element)

      #expect(values.category == .text)
      #expect(values.fontFamily == "Inter, sans-serif")
      #expect(values.color == "rgb(255, 255, 255)")
      #expect(values.fontSize == 48)
      #expect(values.isBold)
      #expect(!values.isItalic)
      #expect(values.textAlign == .center)
      #expect(values.letterSpacing == "0.5px")
      #expect(values.lineHeight == "56px")
      #expect(values.textContent == "Hello World")
    }

    @Test("Parses button element")
    @MainActor
    func buttonElement() {
      let element = ElementInspectorData(
        tagName: "BUTTON",
        elementId: "",
        className: "cta",
        textContent: "View Menu",
        outerHTML: "<button>View Menu</button>",
        cssSelector: "button.cta",
        computedStyles: [
          "backgroundColor": "rgb(220, 38, 38)",
          "color": "rgb(255, 255, 255)",
          "fontSize": "18px",
          "fontWeight": "600",
          "borderRadius": "8px",
          "paddingTop": "12px",
          "paddingRight": "20px",
          "paddingBottom": "12px",
          "paddingLeft": "20px",
        ],
        boundingRect: CGRect(x: 100, y: 200, width: 160, height: 48)
      )

      let values = DesignToolbarValues(element: element)

      #expect(values.category == .button)
      #expect(values.category.supportsTextControls)
      #expect(values.category.supportsBackgroundColor)
      #expect(values.backgroundColor == "rgb(220, 38, 38)")
      #expect(values.isBold)
      #expect(values.borderRadius == "8px")
      #expect(values.padding == "12px 20px")
    }

    @Test("Defaults for missing styles")
    @MainActor
    func defaultValues() {
      let element = ElementInspectorData(
        tagName: "DIV",
        elementId: "",
        className: "",
        textContent: "",
        outerHTML: "<div></div>",
        cssSelector: "div",
        computedStyles: [:],
        boundingRect: .zero
      )

      let values = DesignToolbarValues(element: element)

      #expect(values.category == .container)
      #expect(values.fontFamily == "sans-serif")
      #expect(values.fontSize == 16)
      #expect(!values.isBold)
      #expect(!values.isItalic)
      #expect(values.textAlign == .left)
    }
  }

  // MARK: - Color parsing

  @Suite("Color parsing")
  struct ColorParsingTests {

    @Test("Parse rgb()")
    func parseRGB() {
      let color = CSSParser.parseColor("rgb(255, 0, 128)")
      let srgb = color.usingColorSpace(.sRGB)!
      #expect(abs(srgb.redComponent - 1.0) < 0.01)
      #expect(abs(srgb.greenComponent - 0.0) < 0.01)
      #expect(abs(srgb.blueComponent - 128.0 / 255.0) < 0.01)
    }

    @Test("Parse rgba()")
    func parseRGBA() {
      let color = CSSParser.parseColor("rgba(0, 0, 0, 0.5)")
      let srgb = color.usingColorSpace(.sRGB)!
      #expect(abs(srgb.alphaComponent - 0.5) < 0.01)
    }

    @Test("Parse hex")
    func parseHex() {
      let color = CSSParser.parseColor("#FF0000")
      let srgb = color.usingColorSpace(.sRGB)!
      #expect(abs(srgb.redComponent - 1.0) < 0.01)
      #expect(abs(srgb.greenComponent - 0.0) < 0.01)
    }

    @Test("Parse transparent")
    func parseTransparent() {
      let color = CSSParser.parseColor("transparent")
      let srgb = color.usingColorSpace(.sRGB)!
      #expect(abs(srgb.alphaComponent - 0.0) < 0.01)
    }

    @Test("Serialize color roundtrip")
    func serializeRoundtrip() {
      let original = "rgb(100, 200, 50)"
      let color = CSSParser.parseColor(original)
      let serialized = CSSParser.serializeColor(color)
      #expect(serialized == "rgb(100, 200, 50)")
    }
  }
}
