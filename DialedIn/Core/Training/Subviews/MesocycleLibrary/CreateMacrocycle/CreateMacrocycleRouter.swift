//
//  CreateMacrocycleRouter.swift
//  DialedIn
//

@MainActor
protocol CreateMacrocycleRouter: GlobalRouter { }

extension CoreRouter: CreateMacrocycleRouter { }
