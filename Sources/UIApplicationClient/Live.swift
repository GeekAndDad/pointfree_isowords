import Combine
import UIKit

@available(iOSApplicationExtension, unavailable)
extension UIApplicationClient {
  public static let live = Self(
    alternateIconName: { UIApplication.shared.alternateIconName },
    alternateIconNameAsync: { await UIApplication.shared.alternateIconName },
    open: { @MainActor in await UIApplication.shared.open($0, options: $1) },
    openSettingsURLString: { await UIApplication.openSettingsURLString },
    setAlternateIconName: { @MainActor in try await UIApplication.shared.setAlternateIconName($0) },
    supportsAlternateIcons: { UIApplication.shared.supportsAlternateIcons },
    supportsAlternateIconsAsync: { await UIApplication.shared.supportsAlternateIcons }
  )
}
