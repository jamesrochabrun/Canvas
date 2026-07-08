import Testing
@testable import Canvas

@Suite("TweaksGenerationStatus")
struct TweaksGenerationStatusTests {

  @Test func activeStatusesReportActive() {
    #expect(TweaksGenerationStatus.queued.isActive)
    #expect(TweaksGenerationStatus.running(activity: nil).isActive)
    #expect(TweaksGenerationStatus.running(activity: "Editing index.html").isActive)
    #expect(TweaksGenerationStatus.waitingToApply.isActive)
  }

  @Test func terminalAndIdleStatusesReportInactive() {
    #expect(!TweaksGenerationStatus.idle.isActive)
    #expect(!TweaksGenerationStatus.applied.isActive)
    #expect(!TweaksGenerationStatus.failed(message: "boom").isActive)
    #expect(!TweaksGenerationStatus.conflict.isActive)
  }

  @Test func equalityDistinguishesAssociatedValues() {
    #expect(TweaksGenerationStatus.running(activity: "a") != .running(activity: "b"))
    #expect(TweaksGenerationStatus.running(activity: nil) == .running(activity: nil))
    #expect(TweaksGenerationStatus.failed(message: "x") == .failed(message: "x"))
    #expect(TweaksGenerationStatus.failed(message: "x") != .failed(message: "y"))
  }
}
