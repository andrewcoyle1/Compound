//
//  DeleteAccountView.swift
//  Compound
//

import SwiftUI
import StoreKit

struct DeleteAccountView: View {

    @State var presenter: DeleteAccountPresenter

    var body: some View {
        Group {
            if presenter.isDeleted {
                deletedContent
            } else {
                confirmationList
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(presenter.isDeleting || presenter.isDeleted)
        // Pushed inside the Profile sheet. Once the account is gone, swiping the sheet away would
        // leave a signed-out app behind it, so Done is the only way on.
        .interactiveDismissDisabled(presenter.isDeleting || presenter.isDeleted)
        .manageSubscriptionsSheet(isPresented: $presenter.isManageSubscriptionsPresented)
        .onAppear {
            presenter.onViewAppear()
        }
    }

    private var confirmationList: some View {
        List {
            Section {
                Label("Your profile, username and photos", systemImage: Symbol.profile)
                Label("Workouts, mesocycles, exercises and gym profiles", systemImage: Symbol.workout)
                Label("Meals, foods and recipes", systemImage: Symbol.meal)
                Label("Body measurements, goals and progress photos", systemImage: Symbol.measurement)
                Label("Comments, likes and follows", systemImage: Symbol.friends)
            } header: {
                Text("What Is Deleted")
            } footer: {
                Text("Your account is closed straight away, and the rest of your data is removed from our servers within 30 days. This cannot be undone.")
            }

            Section {
                ListRowButton(title: String(localized: "Manage Subscription"), accessory: .none) {
                    presenter.onManageSubscriptionPressed()
                }
            } header: {
                Text("Subscription")
            } footer: {
                Text("Your subscription is billed by Apple and is not canceled by deleting your account. Cancel it here first if you do not want to be charged again.")
            }

            Section {
                Button(role: .destructive) {
                    presenter.onDeletePressed()
                } label: {
                    Text("Delete Account")
                }
                .disabled(presenter.isDeleting)
            } footer: {
                if presenter.asksToSignInAgain {
                    Text("You'll be asked to sign in again to confirm.")
                }
            }
        }
    }

    private var deletedContent: some View {
        ContentUnavailableView {
            Label("Account Deleted", systemImage: Symbol.success)
        } description: {
            Text("The rest of your data is removed from our servers within 30 days.")
        } actions: {
            CallToActionButton {
                presenter.onDonePressed()
            } label: {
                Text("Done")
            }
        }
    }
}

extension CoreBuilder {
    func deleteAccountView(router: AnyRouter) -> some View {
        DeleteAccountView(
            presenter: DeleteAccountPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showDeleteAccountView() {
        router.showScreen(.push) { router in
            builder.deleteAccountView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.deleteAccountView(router: router)
    }
}
