//
//  CalendarRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 26/01/2026.
//

@MainActor
protocol CalendarRouter: GlobalRouter { }

extension CoreRouter: CalendarRouter { }
