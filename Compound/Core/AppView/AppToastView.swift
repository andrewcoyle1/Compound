//
//  AppToastView.swift
//  Compound
//
//  Created by Andrew Coyle on 22/09/2026.
//

import SwiftUI

/// The app-level toast. Shaped like `ActivityNotificationBannerView` so the two read as the same
/// piece of furniture when either one appears.
struct AppToastView: View {

    let toast: AppToast

    private var iconName: String {
        switch toast.style {
        case .progress: return "arrow.clockwise"
        case .success:  return Symbol.success
        case .failure:  return Symbol.error + ".fill"
        }
    }

    private var iconColour: Color {
        switch toast.style {
        case .progress: return .secondary
        case .success:  return .success
        case .failure:  return .danger
        }
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: iconName)
                .foregroundStyle(iconColour)
                .font(.rowDetail)

            Text(toast.message)
                .font(.rowDetail)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, Spacing.xl)
        .accessibilityElement(children: .combine)
        // It appears over whatever the person is doing, so VoiceOver has to be told.
        .task(id: toast.message) {
            AccessibilityNotification.Announcement(toast.message).post()
        }
    }
}

#Preview {
    VStack {
        AppToastView(toast: AppToast(style: .progress, message: "Couldn't save your workout. Retrying…"))
        AppToastView(toast: AppToast(style: .success, message: "Workout saved."))
        AppToastView(toast: AppToast(
            style: .failure,
            message: "Couldn't save your workout. It's still on this device — resume it from Training."
        ))
    }
    .padding(.top, Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.gray.opacity(0.2))
}
