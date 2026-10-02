//
//  IntroRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol IntroRouter: GlobalRouter {
    func showAuthView()
}

extension CoreRouter: IntroRouter { }
