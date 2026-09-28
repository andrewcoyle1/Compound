import SwiftUI

extension GlobalRouter {

    /// Reports a failed action by name. Offline gets the shared offline alert; anything else gets
    /// `title` and a next step, never `error.localizedDescription`, which reads like "INTERNAL" or
    /// "The data couldn't be read because it isn't in the correct format." and is not translated.
    /// The raw error belongs in analytics.
    func showFailure(_ title: String, error: Error) {
        if error.isOfflineError {
            showAlert(error: error)
        } else {
            showSimpleAlert(title: title, subtitle: String(localized: "Something went wrong. Please try again."))
        }
    }
}
