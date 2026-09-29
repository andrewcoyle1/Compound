//
//  AuthorHeader.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct AuthorHeaderDelegate {
    let author: UserModel
    let date: Date
}

struct AuthorHeaderView: View {
    
    @State var presenter: AuthorHeaderPresenter
    let delegate: AuthorHeaderDelegate
    
    var body: some View {
        HStack(spacing: 10) {
            ImageLoaderView(
                urlString: delegate.author.profileImageNameCalculated ?? Constants.randomImage,
                clipShape: AnyShape(.circle)
            )
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                // The handle drops under the name once both no longer fit on one line.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) { nameAndHandle }
                    VStack(alignment: .leading, spacing: 2) { nameAndHandle }
                }
                Text(delegate.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .anyButton {
            presenter.onUserPressed(author: delegate.author)
        }
        .accessibilityHint("Opens their profile")
    }

    @ViewBuilder
    private var nameAndHandle: some View {
        if let name = delegate.author.fullNameCalculated {
            Text(name)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        UsernameLabel(username: delegate.author.username)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = AuthorHeaderDelegate(author: .mock, date: .now)
    
    RouterView { router in
        builder.authorHeaderView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    func authorHeaderView(router: AnyRouter, delegate: AuthorHeaderDelegate) -> some View {
        AuthorHeaderView(
            presenter: AuthorHeaderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}
