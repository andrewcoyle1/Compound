//
//  ProfileButton.swift
//  DialedIn
//
//  Created by Andrew Coyle on 18/03/2026.
//

import SwiftUI

struct ProfileButton: View {
    
    let avatarSize: CGFloat = ControlSize.thumbnail
    let action: () -> Void
    let imageUrl: String?
    
    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if let imageUrl {
                    ImageLoaderView(urlString: imageUrl, clipShape: AnyShape(Circle()))
                        .frame(width: avatarSize, height: avatarSize)
                } else {
                    Image(systemName: Symbol.profile)
                        .iconSize(.medium)
                }
            }
        }
        .accessibilityLabel("Profile")
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)

    }
}

#Preview {
    NavigationStack {
        Color.clear.ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton(
                        action: {
                            
                        },
                        imageUrl: Constants.randomImage
                    )
                }
            }
    }
}
