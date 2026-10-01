//
//  SharedItemRouter.swift
//  Compound
//

@MainActor
protocol SharedItemRouter: GlobalRouter { }

extension CoreRouter: SharedItemRouter { }
