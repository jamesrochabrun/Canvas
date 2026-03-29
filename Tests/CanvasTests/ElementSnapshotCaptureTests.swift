import Testing
@testable import Canvas

@Suite("ElementSnapshotCapture")
struct ElementSnapshotCaptureTests {

  // MARK: - SnapshotError

  @Test func zeroRectErrorIsDistinct() {
    let error = SnapshotError.zeroRect
    #expect(error == .zeroRect)
  }

  @Test func rectOutOfBoundsErrorIsDistinct() {
    let error = SnapshotError.rectOutOfBounds
    #expect(error == .rectOutOfBounds)
  }

  @Test func snapshotFailedCarriesMessage() {
    let error = SnapshotError.snapshotFailed("timeout")
    if case .snapshotFailed(let message) = error {
      #expect(message == "timeout")
    } else {
      Issue.record("Expected snapshotFailed case")
    }
  }

  @Test func snapshotErrorConformsToSendable() {
    let error: any Sendable = SnapshotError.zeroRect
    #expect(error is SnapshotError)
  }

  @Test func snapshotErrorConformsToError() {
    let error: any Error = SnapshotError.zeroRect
    #expect(error is SnapshotError)
  }
}
