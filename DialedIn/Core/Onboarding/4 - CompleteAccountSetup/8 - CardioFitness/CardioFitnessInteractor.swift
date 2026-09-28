//
//  CardioFitnessInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CardioFitnessInteractor: GlobalInteractor { }

extension CoreInteractor: CardioFitnessInteractor { }
