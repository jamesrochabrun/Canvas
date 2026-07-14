//
//  TweaksPromptBuilder.swift
//  WebInspector
//
//  Constructs the prompts sent to the agent asking it to add tweakable
//  controls (dc_set_props declarations) to the previewed design file, or to
//  remove the tweaks integration entirely.
//

import Foundation

/// Builds agent prompts for the tweaks panel's "Ideas" and custom-description actions.
public enum TweaksPromptBuilder {

  /// Prompt asking the agent to study the design and invent additional expressive controls.
  public static func ideasPrompt(
    fileName: String,
    existingProps: [TweakProp] = []
  ) -> String {
    """
    Add additional tweakable controls to \(fileName) (declare with dc_set_props, read via this.props): \
    first read the entire file and understand the existing tweak schema and render behavior, then \
    add two or three new expressive controls that reshape the feel, not single-property pixel-pushing. \
    The new controls must be meaningfully different from every existing control.

    \(existingPropsReference(existingProps))

    \(contractReference)
    """
  }

  /// Prompt asking the agent to add tweakable controls per the user's own description.
  public static func customPrompt(fileName: String, instruction: String) -> String {
    """
    Add tweakable controls to \(fileName) (declare with dc_set_props, read via this.props): \
    \(instruction)

    \(contractReference)
    """
  }

  /// Prompt asking the agent to remove the complete tweaks integration from a file.
  ///
  /// Unlike the creation prompts, this deliberately omits the shared contract
  /// block — the agent is tearing the integration out, not producing
  /// declarations for the panel to consume.
  public static func deleteAllPrompt(fileName: String) -> String {
    """
    Remove the complete tweaks integration from \(fileName). The design must keep looking and \
    behaving exactly as it does right now with the current default values — only the tweak \
    machinery goes away.

    Work directly and only edit the named design file. Do not start a dev server, inspect \
    unrelated files, or explain the change; finish as soon as the file contains a valid \
    implementation.

    Removal requirements:
    - Read the complete file first and trace how each declared prop reaches the render function, \
    DOM, and CSS before deleting anything.
    - Delete the dc_set_props call and its schema declaration, and the dc_on_props_changed \
    assignment.
    - Replace every var(--tweak-<name>, <fallback>) reference with its fallback value, then remove \
    the tweak-only custom properties themselves.
    - Remove data-tweak attributes, this.props/window.props reads, dc:propschange event listeners, \
    and any DOM elements, styles, or helper functions that exist solely to support tweaks.
    - Preserve every unrelated piece of design and behavior exactly as it is.
    """
  }

  /// Shared contract block appended to every tweaks prompt so the agent
  /// produces declarations the native panel and persister can consume.
  static let contractReference = """
    Work directly and only edit the named design file. Do not start a dev server, inspect unrelated files, \
    or explain the change; finish as soon as the file contains a valid implementation.

    Cumulative editing requirements:
    - Read the complete file before editing. Inventory the existing dc_set_props entries and trace how \
    each one affects the render function, DOM, and CSS before proposing anything new.
    - If dc_set_props already exists, extend its existing object literal in place. Preserve every existing \
    prop's name, label, type, range/options, current default value, order, and behavior exactly. Do not \
    replace the declaration, create a second call, rename or delete props, or reset their values unless \
    the user's instruction explicitly asks to change a specific existing control.
    - Avoid duplicates by comparing both names/labels and behavior. A differently named control is still \
    a duplicate if it manipulates the same visual or behavioral dimension as an existing control.
    - Extend the existing render function so it continues applying every old prop and also applies each \
    new prop. Only create a fresh declaration and render function when the file has none.

    Tweakable props contract:
    - Call dc_set_props exactly once, at the top level of an inline <script>, with a single \
    plain JSON object literal as its only argument (double-quoted keys and strings, literal \
    scalar "value" fields — no expressions, variables, or spreads).
    - Each key is a prop name mapping to an object: {"label": String, "type": "slider" | \
    "select" | "color" | "toggle" | "text", "value": <default>}. Sliders also take "min", \
    "max", and "step" (numbers) with a number "value"; selects take "options" (array of \
    strings) and a string "value" that is one of the options; colors use a hex string like \
    "#ff6b35"; toggles use true or false.
    - Read current values via this.props.<name> (equivalently window.props.<name>). Do not \
    redefine dc_set_props or reassign window.props.
    - Define a render function that reads this.props and applies every prop to the DOM/CSS, \
    assign it with `dc_on_props_changed = render;`, and call render() once after \
    dc_set_props so the page reflects the defaults.

    Example:
    <script>
      dc_set_props({
        "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 },
        "vibe": { "label": "Vibe", "type": "select", "options": ["calm", "electric", "retro"], "value": "calm" }
      });
      function render() { /* read this.props and update styles */ }
      dc_on_props_changed = render;
      render();
    </script>
    """

  private static func existingPropsReference(_ props: [TweakProp]) -> String {
    guard !props.isEmpty else {
      return "The live page currently reports no existing tweak controls; still verify the file before creating them."
    }

    let inventory = props.map { prop in
      "- \(prop.name): \(prop.label) [\(prop.type.rawValue)]"
    }.joined(separator: "\n")
    return """
      Existing controls currently reported by the live page (all must be preserved):
      \(inventory)
      """
  }
}
