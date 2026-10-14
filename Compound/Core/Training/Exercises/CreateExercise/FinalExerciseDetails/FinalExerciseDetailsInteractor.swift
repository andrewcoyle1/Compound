import SwiftUI

@MainActor
protocol FinalExerciseDetailsInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
}

extension CoreInteractor: FinalExerciseDetailsInteractor { }
