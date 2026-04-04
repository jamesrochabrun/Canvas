//
//  WebInspectCropInputOverlay.swift
//  Canvas
//
//  Wraps WebInspectCropInputView with selection-anchored placement after
//  the user draws a crop rectangle in crop inspect mode.
//

import SwiftUI

/// Overlay that positions the crop input view just below the crop rectangle,
/// using the same layout resolver as the inspection mode input.
struct WebInspectCropInputOverlay: View {
  @Bindable var state: ElementInspectState
  let onSubmit: ((CGRect, [ElementInspectorData], String) -> Void)?

  @State private var measuredHeight: CGFloat = Self.defaultHeight

  private static let defaultHeight: CGFloat = 120
  private let contentInset: CGFloat = 12
  private let gap: CGFloat = 12

  var body: some View {
    GeometryReader { geometry in
      if let cropRect = state.cropRect {
        cropInputView(cropRect: cropRect)
          .padding(.horizontal, contentInset)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .offset(y: resolvedTopOffset(
            for: cropRect,
            containerHeight: geometry.size.height
          ))
      }
    }
  }

  private func resolvedTopOffset(for cropRect: CGRect, containerHeight: CGFloat) -> CGFloat {
    WebInspectInputLayoutResolver.resolve(
      containerHeight: containerHeight,
      elementRect: cropRect,
      inputHeight: measuredHeight,
      topInset: contentInset,
      bottomInset: contentInset,
      gap: gap
    ).topOffset
  }

  private func cropInputView(cropRect: CGRect) -> some View {
    WebInspectCropInputView(
      cropRect: cropRect,
      elementCount: state.cropElements.count,
      onSubmit: { instruction in
        onSubmit?(cropRect, state.cropElements, instruction)
        state.deactivate()
      },
      onDismiss: {
        state.dismissCropRect()
      }
    )
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear {
            measuredHeight = max(Self.defaultHeight, proxy.size.height)
          }
          .onChange(of: proxy.size.height) { _, newHeight in
            measuredHeight = max(Self.defaultHeight, newHeight)
          }
      }
    }
  }
}
