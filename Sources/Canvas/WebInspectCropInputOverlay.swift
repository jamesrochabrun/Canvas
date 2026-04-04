//
//  WebInspectCropInputOverlay.swift
//  Canvas
//
//  Wraps WebInspectCropInputView with bottom placement after
//  the user draws a crop rectangle in crop inspect mode.
//

import SwiftUI

/// Overlay that positions the crop input view at the bottom of the preview.
struct WebInspectCropInputOverlay: View {
  @Bindable var state: ElementInspectState
  let onSubmit: ((CGRect, [ElementInspectorData], String) -> Void)?

  var body: some View {
    if let cropRect = state.cropRect {
      WebInspectCropInputView(
        cropRect: cropRect,
        elementCount: state.cropElements.count,
        onSubmit: { instruction in
          onSubmit?(cropRect, state.cropElements, instruction)
          state.dismissCropRect()
        },
        onDismiss: {
          state.dismissCropRect()
        }
      )
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
  }
}
