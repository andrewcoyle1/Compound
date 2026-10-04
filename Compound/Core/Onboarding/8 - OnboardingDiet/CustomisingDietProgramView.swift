//
//  CustomisingDietProgramView.swift
//  Compound
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct CustomisingDietProgramView: View {

    @State var presenter: CustomisingDietProgramPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Ready to Plan Meals?",
            progress: OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Use Recommended Plan", identifier: "UseRecommendedPlan") { presenter.onUseRecommendedPlanPressed() },
            secondary: .init(title: "Customize", identifier: "Customize") { presenter.navigateToPreferredDiet() },
            onDevSettingsPressed: nil
        ) {
            Section {
                Text("Let's get to work creating a custom diet program tuned to your needs. This will evolve over time as we learn how your body responds to the diet and make the necessary changes. This can always be manually altered later if you would like a specific change.")
            } header: {
                Text("Diet Program")
            } footer: {
                Text("Use the recommended plan, or answer a few questions to customize it.")
            }
        }
    }

}

extension CoreBuilder {
    func customisingDietProgramView(router: AnyRouter) -> some View {
        CustomisingDietProgramView(
            presenter: CustomisingDietProgramPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    /// Reached from the gym profile's router once the training mesocycle is activated, several
    /// screens below the top. `.append` puts it on top; the default `.insert` slotted it in
    /// behind the mesocycle screens and rebuilt them with a blank mesocycle instead.
    func showCustomisingDietProgramView() {
        router.showScreen(.push, location: .append) { router in
            builder.customisingDietProgramView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.customisingDietProgramView(router: router)
    }
    
}
