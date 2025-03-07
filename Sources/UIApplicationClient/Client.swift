import ComposableArchitecture
import UIKit

public struct UIApplicationClient {
  // TODO: Should these endpoints be merged and `@MainActor`? Should `Reducer` be `@MainActor`?
  public var alternateIconName: () -> String?
  public var alternateIconNameAsync: @Sendable () async -> String?
  public var open: @Sendable (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
  public var openSettingsURLString: @Sendable () async -> String
  public var setAlternateIconName: @Sendable (String?) async throws -> Void
  // TODO: Should these endpoints be merged and `@MainActor`? Should `Reducer` be `@MainActor`?
  @available(*, deprecated) public var supportsAlternateIcons: () -> Bool
  public var supportsAlternateIconsAsync: @Sendable () async -> Bool
}
