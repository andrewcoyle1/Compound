//
//  CalendarInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 26/01/2026.
//

@MainActor
protocol CalendarInteractor {
    func trackEvent(event: LoggableEvent)
    func trackScreenEvent(event: LoggableEvent)
}

extension CoreInteractor: CalendarInteractor { }
