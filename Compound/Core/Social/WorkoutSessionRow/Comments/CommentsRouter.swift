//
//  CommentsRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 08/03/2026.
//

@MainActor
protocol CommentsRouter: GlobalRouter { }

extension CoreRouter: CommentsRouter { }
