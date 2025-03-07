import ApiClient
import ComposableArchitecture
import Overture
import SharedModels
import Styleguide
import SwiftUI

@testable import HomeFeature

@main
struct HomeFeaturePreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        HomeView(
          store: Store(
            initialState: .init(),
            reducer: homeReducer,
            environment: HomeEnvironment(
              apiClient: update(.noop) {
                $0.authenticate = { _ in .init(appleReceipt: nil, player: .blob) }
                $0.override(
                  route: .dailyChallenge(.today(language: .en)),
                  withResponse: {
                    try await OK([
                      FetchTodaysDailyChallengeResponse(
                        dailyChallenge: .init(
                          endsAt: .init(),
                          gameMode: .timed,
                          id: .init(rawValue: UUID()),
                          language: .en
                        ),
                        yourResult: .init(
                          outOf: .random(in: 2000...4000),
                          rank: 10,
                          score: 3_000
                        )
                      )
                    ])
                  }
                )
              },
              applicationClient: .noop,
              audioPlayer: .noop,
              backgroundQueue: DispatchQueue.global(qos: .background).eraseToAnyScheduler(),
              build: .noop,
              database: .live(path: URL(string: ":memory:")!),
              deviceId: .noop,
              feedbackGenerator: .live,
              fileClient: .live,
              gameCenter: .noop,
              lowPowerMode: .live,
              mainQueue: .main,
              mainRunLoop: .main,
              remoteNotifications: .noop,
              serverConfig: .noop,
              setUserInterfaceStyle: { _ in },
              storeKit: .noop,
              timeZone: { TimeZone.current },
              userDefaults: .noop,
              userNotifications: .noop
            )
          )
        )
      }
    }
  }
}
