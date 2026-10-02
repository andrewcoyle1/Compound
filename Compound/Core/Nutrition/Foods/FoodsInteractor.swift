//
//  FoodsInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol FoodsInteractor: GlobalInteractor { }

extension CoreInteractor: FoodsInteractor { }
