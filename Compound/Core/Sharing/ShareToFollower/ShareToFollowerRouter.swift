//
//  ShareToFollowerRouter.swift
//  Compound
//

@MainActor
protocol ShareToFollowerRouter: GlobalRouter { }

extension CoreRouter: ShareToFollowerRouter { }
