/// The state of the focused agent task that creates tweak controls.
public enum TweaksAgentState: Equatable, Sendable {
  case idle
  case working
  case failed(String)
  case conflict
}
