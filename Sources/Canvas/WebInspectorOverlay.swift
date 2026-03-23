//
//  WebInspectorOverlay.swift
//  WebInspector
//
//  View modifier that adds the element inspector overlay (banner + input)
//  to any view. Works with InspectableWebView or any custom WKWebView setup.
//

import SwiftUI

// MARK: - WebInspectorOverlay

/// Adds the inspect-mode banner and floating input overlay to the modified view.
///
/// Usage:
/// ```swift
/// @State var inspectState = ElementInspectState()
///
/// InspectableWebView(url: myURL, ...)
///   .webInspectorOverlay(state: inspectState) { element, instruction in
///     let prompt = ElementInspectorPromptBuilder.buildPrompt(
///       element: element, instruction: instruction
///     )
///     // send prompt to your agent
///   }
/// ```
struct WebInspectorOverlayModifier: ViewModifier {
  @Bindable var state: ElementInspectState
  let onSubmit: ((ElementInspectorData, String) -> Void)?
  let onContextSelection: ((ElementInspectorData) -> Void)?

  func body(content: Content) -> some View {
    ZStack(alignment: .bottom) {
      content

      // Top banner
      if state.isActive, !state.isInputShowing {
        VStack {
          HStack(spacing: 6) {
            Image(systemName: "cursorarrow.click.2")
              .font(.system(size: 12))
              .foregroundColor(.white)
            Text(state.isContextMode
              ? "Context Mode — click elements to capture"
              : "Inspect Mode — click any element")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(.white)
            Spacer()
            Button {
              state.deactivate()
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Exit inspect mode (Esc)")
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.accentColor.opacity(0.85))
          Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      // Bottom overlay — branched by mode
      if let element = state.selectedElement {
        Group {
          switch state.mode {
          case .input:
            WebInspectInputView(
              element: element,
              onSubmit: { instruction in
                onSubmit?(element, instruction)
                state.deactivate()
              },
              onDismiss: {
                state.dismissInput()
              }
            )

          case .context:
            WebInspectContextView(
              element: element,
              onDismiss: {
                state.deactivate()
              }
            )
          }
        }
        .padding(12)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
    }
    .animation(.easeOut(duration: 0.2), value: state.isActive)
    .animation(.easeOut(duration: 0.15), value: state.selectedElement?.id)
    .onChange(of: state.selectedElement?.id) { _, newValue in
      guard newValue != nil,
            state.isContextMode,
            let element = state.selectedElement else { return }
      onContextSelection?(element)
      state.dismissInput()
    }
  }
}

// MARK: - View Extension

public extension View {
  /// Adds the web element inspector overlay (banner + floating input) to this view.
  ///
  /// - Parameters:
  ///   - state: The shared `ElementInspectState` controlling the inspector lifecycle.
  ///   - onSubmit: Called with the selected element and the user's instruction when they press Enter (input mode).
  ///   - onContextSelection: Called with the selected element immediately on click (context mode).
  func webInspectorOverlay(
    state: ElementInspectState,
    onSubmit: ((ElementInspectorData, String) -> Void)? = nil,
    onContextSelection: ((ElementInspectorData) -> Void)? = nil
  ) -> some View {
    modifier(WebInspectorOverlayModifier(
      state: state,
      onSubmit: onSubmit,
      onContextSelection: onContextSelection
    ))
  }
}
