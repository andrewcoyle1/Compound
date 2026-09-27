//
//  MealAccessoryInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol MealAccessoryInteractor: GlobalInteractor { }

extension CoreInteractor: MealAccessoryInteractor { }
