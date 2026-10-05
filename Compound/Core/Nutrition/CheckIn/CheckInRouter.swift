//
//  CheckInRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol CheckInRouter: GlobalRouter, AskCoachRouter {

}

extension CoreRouter: CheckInRouter { }
