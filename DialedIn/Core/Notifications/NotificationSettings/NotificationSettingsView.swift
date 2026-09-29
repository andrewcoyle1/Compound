//
//  NotificationSettingsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/09/2026.
//

import SwiftUI

struct NotificationSettingsDelegate {
    
}

struct NotificationSettingsView: View {
    
    let delegate: NotificationSettingsDelegate
    @State var presenter: NotificationSettingsPresenter
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

extension CoreBuilder {
    
    func notificationSettingsView(delegate: NotificationSettingsDelegate, router: AnyRouter) -> some View {
        NotificationSettingsView(
            delegate: delegate,
            presenter: NotificationSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            )
        )
    }
}

extension CoreRouter {
    
    func showNotificationSettingsView(delegate: NotificationSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.notificationSettingsView(delegate: delegate, router: router)
        }
    }
}
#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NotificationSettingsDelegate()
    RouterView { router in
        builder.notificationSettingsView(delegate: delegate, router: router)
    }
    
}
