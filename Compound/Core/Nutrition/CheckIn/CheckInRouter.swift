//
//  CheckInRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol CheckInRouter: GlobalRouter {

}

extension CoreRouter: CheckInRouter { }
