//
//  EditDayOrderRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol EditDayOrderRouter: GlobalRouter { }

extension CoreRouter: EditDayOrderRouter { }
