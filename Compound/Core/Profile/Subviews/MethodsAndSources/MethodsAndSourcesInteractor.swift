import SwiftUI

@MainActor
protocol MethodsAndSourcesInteractor: GlobalInteractor { }

extension CoreInteractor: MethodsAndSourcesInteractor { }
