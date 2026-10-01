//
//  CreateChallengeRouter.swift
//  Compound
//

@MainActor
protocol CreateChallengeRouter: GlobalRouter { }

extension CoreRouter: CreateChallengeRouter { }
