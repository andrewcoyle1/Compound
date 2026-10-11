import SwiftUI

@MainActor
protocol WeeklyTargetsInteractor: GlobalInteractor { }

extension CoreInteractor: WeeklyTargetsInteractor { }
