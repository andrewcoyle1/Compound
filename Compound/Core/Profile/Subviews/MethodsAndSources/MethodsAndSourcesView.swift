//
//  MethodsAndSourcesView.swift
//  Compound
//
//  Settings › Methods & Sources: every calculation the app shows with an ⓘ, in one list, so the
//  sources can be read without hunting for the screen that uses them.
//

import SwiftUI

struct MethodsAndSourcesDelegate {

}

struct MethodsAndSourcesView: View {

    @State var presenter: MethodsAndSourcesPresenter
    let delegate: MethodsAndSourcesDelegate

    @State private var selectedMethod: MethodInfo?

    var body: some View {
        List {
            Section {
                ForEach(presenter.methods) { method in
                    ListRowButton(title: String(localized: method.title), accessory: .chevron) {
                        presenter.onMethodPressed(method)
                        selectedMethod = method
                    }
                }
            } footer: {
                Text("Each figure Compound calculates for you has an \(Image(systemName: Symbol.info)) beside it that opens the same explanation.")
            }
        }
        .navigationTitle("Methods & Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMethod) { method in
            MethodInfoSheet(info: method)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {

    func methodsAndSourcesView(router: AnyRouter, delegate: MethodsAndSourcesDelegate) -> some View {
        MethodsAndSourcesView(
            presenter: MethodsAndSourcesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showMethodsAndSourcesView(delegate: MethodsAndSourcesDelegate) {
        router.showScreen(.push) { router in
            builder.methodsAndSourcesView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.methodsAndSourcesView(router: router, delegate: MethodsAndSourcesDelegate())
    }
}
