import SwiftUI

@MainActor
protocol CreateGymProfileInteractor: GlobalInteractor {
    var userId: String? { get }
}

extension CoreInteractor: CreateGymProfileInteractor { }
