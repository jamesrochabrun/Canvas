import JavaScriptCore
import Testing
@testable import Canvas

@Suite("Inspector script generation")
struct InspectorScriptGenerationTests {

  private static let allLevels: [ElementInspectorDataLevel] = [.regular, .full]

  @Test(arguments: allLevels)
  func includesContentFrameSupport(level: ElementInspectorDataLevel) {
    let script = ElementInspectorBridge.inspectorJS(for: level)
    #expect(script.contains("resolveInspectionContext"))
    #expect(script.contains("toTopViewportRect"))
    #expect(script.contains("frameContentOffset"))
    #expect(script.contains("watchForContentFrameIfMissing"))
    for selector in ElementInspectorBridge.defaultContentFrameSelectors {
      #expect(script.contains(selector))
    }
  }

  /// Guards the content-frame refactor: interaction listeners, hit-testing, and
  /// overlay creation must target the resolved inspection context, never the
  /// top document directly.
  @Test(arguments: allLevels)
  func doesNotBindInteractionToTopDocument(level: ElementInspectorDataLevel) {
    let script = ElementInspectorBridge.inspectorJS(for: level)
    #expect(!script.contains("document.addEventListener"))
    #expect(!script.contains("document.removeEventListener"))
    #expect(!script.contains("document.elementFromPoint"))
    #expect(!script.contains("document.body.querySelectorAll"))
    #expect(!script.contains("document.body.appendChild"))
    #expect(!script.contains("document.body.style.cursor"))
    #expect(!script.contains("window.scrollX"))
    #expect(!script.contains("window.scrollY"))
    #expect(!script.contains("window.getComputedStyle"))
  }

  @Test(arguments: allLevels)
  func leavesNoUnexpandedPlaceholders(level: ElementInspectorDataLevel) {
    let script = ElementInspectorBridge.inspectorJS(for: level)
    #expect(!script.contains("__RELATIONSHIP_HELPERS__"))
    #expect(!script.contains("__PARENT_CONTEXT_CAPTURE__"))
    #expect(!script.contains("__CONTEXT_FIELDS__"))
  }

  @Test(arguments: allLevels)
  func postsMessagesThroughTopWindowBridge(level: ElementInspectorDataLevel) {
    let script = ElementInspectorBridge.inspectorJS(for: level)
    #expect(script.contains("window.webkit.messageHandlers.elementInspector.postMessage"))
  }

  /// Parses the generated script with JavaScriptCore (without executing it) so
  /// a template edit that breaks JS syntax fails in tests instead of silently
  /// disabling inspection at runtime.
  @Test(arguments: allLevels)
  func generatesSyntacticallyValidJavaScript(level: ElementInspectorDataLevel) throws {
    let script = ElementInspectorBridge.inspectorJS(for: level)
    let context = try #require(JSContext())
    context.setObject(script, forKeyedSubscript: "__source" as NSString)
    // `new Function` parses the source but does not run it, so browser-only
    // globals (`document`, `window.webkit`) do not matter here.
    context.evaluateScript(
      "var __parseError = null; try { new Function(__source); } catch (e) { __parseError = String(e); }"
    )
    let parseError = context.objectForKeyedSubscript("__parseError")
    #expect(
      parseError?.isNull == true,
      "Generated inspector JS failed to parse: \(parseError?.toString() ?? "unknown")"
    )
  }
}
