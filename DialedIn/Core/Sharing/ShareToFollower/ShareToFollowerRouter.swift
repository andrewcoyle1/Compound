//
//  ShareToFollowerRouter.swift
//  DialedIn
//

@MainActor
protocol ShareToFollowerRouter: GlobalRouter { }

extension CoreRouter: ShareToFollowerRouter { }
