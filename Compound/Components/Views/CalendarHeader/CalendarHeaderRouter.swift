import SwiftUI

@MainActor
protocol CalendarHeaderRouter {
    func showCalendarViewZoom(
        delegate: CalendarDelegate,
        onDismiss: (() -> Void)?,
        onDidDismiss: (() -> Void)?,
        transitionId: String?,
        namespace: Namespace.ID
    )
}

extension CoreRouter: CalendarHeaderRouter { }
