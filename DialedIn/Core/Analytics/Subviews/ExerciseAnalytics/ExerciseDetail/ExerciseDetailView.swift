//
//  ExerciseDetailView.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct ExerciseDetailDelegate {
    /// Pushed from Analytics, where the system Back button closes it. Search still presents it as
    /// a sheet, which needs its own Close (drawn by the shared `MetricDetailView`).
    var isPushed = false
}

struct ExerciseDetailView: View {

    @State var presenter: ExerciseDetailPresenter
    let delegate: ExerciseDetailDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ExerciseDetailDelegate()

    return RouterView { router in
        builder.exerciseDetailView(router: router, delegate: delegate, templateId: "1", name: "Bench Press")
    }
    
}

extension CoreBuilder {

    func exerciseDetailView(router: AnyRouter, delegate: ExerciseDetailDelegate, templateId: String, name: String, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: ExerciseDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                templateId: templateId,
                name: name
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color? = nil) {
        router.showScreen(delegate.isPushed ? .push : .sheet) { router in
            builder.exerciseDetailView(router: router, delegate: delegate, templateId: templateId, name: name, themeColor: themeColor)
        }
    }
}
