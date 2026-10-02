import SwiftUI

@MainActor
protocol OptimisationRouter: GlobalRouter { }

extension CoreRouter: OptimisationRouter { }
