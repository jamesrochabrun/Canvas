//
//  TweaksGenerationStatus.swift
//  WebInspector
//
//  Host-provided status of a background tweaks-generation job, rendered by
//  TweaksPanelView as a status row. Canvas stays agnostic about how the job
//  runs; the host app drives these transitions.
//

import Foundation

// MARK: - TweaksGenerationStatus

/// Lifecycle of a background "add tweakable controls" job as the panel sees it.
public enum TweaksGenerationStatus: Equatable, Sendable {
  case idle
  case queued
  case running(activity: String?)
  case waitingToApply
  case applied
  case failed(message: String)
  case conflict

  /// True while a job is underway — drives disabling of the panel's
  /// generation controls so a second job can't be submitted mid-run.
  public var isActive: Bool {
    switch self {
    case .queued, .running, .waitingToApply:
      return true
    case .idle, .applied, .failed, .conflict:
      return false
    }
  }
}
