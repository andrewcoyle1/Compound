//
//  SharedItemRouter.swift
//  DialedIn
//

@MainActor
protocol SharedItemRouter: GlobalRouter { }

extension CoreRouter: SharedItemRouter { }
