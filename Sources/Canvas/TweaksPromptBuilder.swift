//
//  TweaksPromptBuilder.swift
//  WebInspector
//
//  Constructs the prompts sent to the agent asking it to add tweakable
//  controls (dc_set_props declarations) to the previewed design file.
//

import Foundation

/// Builds agent prompts for the tweaks panel's "Ideas" and custom-description actions.
public enum TweaksPromptBuilder {

  /// Prompt asking the agent to study the design and invent expressive controls.
  public static func ideasPrompt(fileName: String) -> String {
    """
    Add tweakable controls to \(fileName) (declare with dc_set_props, read via this.props): \
    study this design and add a tweaks panel with two or three expressive controls that \
    reshape the feel, not single-property pixel-pushing

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

  /// Shared contract block appended to every tweaks prompt so the agent
  /// produces declarations the native panel and persister can consume.
  static let contractReference = """
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
}
