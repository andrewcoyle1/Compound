import SwiftUI

/// Only `dismissScreen` and the alerts, which `GlobalRouter` already gives every router.
@MainActor
protocol EditUsernameRouter: GlobalRouter { }

extension CoreRouter: EditUsernameRouter { }
