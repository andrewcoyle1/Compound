import SwiftUI

@MainActor
protocol CalendarHeaderInteractor {
    func trackEvent(event: LoggableEvent)
}

extension CoreInteractor: CalendarHeaderInteractor { }
