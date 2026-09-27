import SwiftUI

struct LicencesDelegate {
    
}

struct LicencesView: View {
    
    @State var presenter: LicencesPresenter
    let delegate: LicencesDelegate
    
    var body: some View {
        List {
            Section {
                Text("Compound is built on the open-source packages below. Thank you to everyone who maintains them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(presenter.groups, id: \.licence) { group in
                Section {
                    ForEach(group.packages) { package in
                        row(for: package)
                    }
                } header: {
                    Text(group.licence)
                }
            }
        }
        .navigationTitle("Licences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    @ViewBuilder
    private func row(for package: Licence) -> some View {
        if let url = package.repositoryURL {
            Link(destination: url) {
                rowLabel(for: package)
            }
            .foregroundStyle(.primary)
        } else {
            rowLabel(for: package)
        }
    }

    private func rowLabel(for package: Licence) -> some View {
        ListRow(title: package.name, subtitle: package.owner)
    }
}

extension CoreBuilder {
    
    func licencesView(router: AnyRouter, delegate: LicencesDelegate) -> some View {
        LicencesView(
            presenter: LicencesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showLicencesView(delegate: LicencesDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.licencesView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = LicencesDelegate()
    
    return RouterView { router in
        builder.licencesView(router: router, delegate: delegate)
    }
    
}
