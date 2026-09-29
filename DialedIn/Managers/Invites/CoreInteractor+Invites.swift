//
//  CoreInteractor+Invites.swift
//  DialedIn
//

import Foundation

@MainActor
protocol InviteLinkInteractor: GlobalInteractor {
    /// The user's invite, created the first time they share it.
    func myInvite() async throws -> InviteModel
}

@MainActor
protocol InviteAcceptInteractor: GlobalInteractor {
    /// Accepts through the `acceptInvite` Cloud Function and returns the inviter's profile.
    func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance)
}

extension CoreInteractor: InviteLinkInteractor, InviteAcceptInteractor {

    func myInvite() async throws -> InviteModel {
        guard let userId = userManager.currentUser?.userId else { throw AppError("Not signed in.") }
        return try await inviteManager.invite(for: userId)
    }

    func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance) {
        let acceptance = try await inviteManager.acceptInvite(code: code)
        guard let inviter = try await userManager.fetchUsers(userIds: [acceptance.inviterId]).first else {
            throw InviteError.notFound
        }
        switch acceptance.youFollow {
        case .following:
            // The server wrote the follow; the user document's listener may not have delivered it
            // yet, so the inviter is added explicitly, as `followUser` does.
            let ids = Array(Set((userManager.currentUser?.followingIds ?? []) + [inviter.userId]))
            async let refreshSessions: () = workoutSessionManager.refreshFollowingSync(followingIds: ids)
            async let refreshProfiles: () = userManager.refreshFollowingUsers(followingIds: ids)
            await refreshSessions
            await refreshProfiles
        case .requested:
            userManager.markFollowRequestSent(to: inviter.userId)
        }
        return (inviter, acceptance)
    }
}

/// Where accepting an invite lands: the inviter's profile.
@MainActor
protocol InviteAcceptRouter: GlobalRouter {
    func showSocialProfileView(delegate: SocialProfileDelegate)
}

/// Accepting an invite, from a `compound://join/` link (via the Dashboard) or a code typed into
/// Search: open the inviter's profile and say what happened, or say why it failed.
@MainActor
struct InviteAcceptFlow {
    let interactor: InviteAcceptInteractor
    let router: InviteAcceptRouter

    func accept(code: String) async {
        guard interactor.ensureOnline(or: router) else { return }
        interactor.trackEvent(eventName: "Invite_Accept_Start", parameters: nil, type: .analytic)
        do {
            let (inviter, acceptance) = try await interactor.acceptInvite(code: code)
            interactor.trackEvent(eventName: "Invite_Accept_Success", parameters: nil, type: .analytic)
            router.showSocialProfileView(delegate: SocialProfileDelegate(user: inviter))
            let name = inviter.firstNameCalculated ?? "your friend"
            interactor.showAppToast(AppToast(style: .success, message: acceptance.message(inviterName: name)))
        } catch {
            interactor.trackEvent(eventName: "Invite_Accept_Fail", parameters: nil, type: .warning)
            router.showSimpleAlert(
                title: "Couldn't accept invite",
                subtitle: (error as? LocalizedError)?.errorDescription ?? "Please try again."
            )
        }
    }
}

/// Sharing the user's invite link: Profile's "Invite a friend" row and the Dashboard's invite card.
/// Creates the invite the first time, then hands the link to the share sheet.
@MainActor
struct InviteShareFlow {
    let interactor: InviteLinkInteractor
    let router: ShareSheetRouter

    func share() async {
        do {
            let invite = try await interactor.myInvite()
            router.showShareSheet(items: [invite.shareMessage])
        } catch {
            router.showSimpleAlert(title: "Couldn't create invite", subtitle: "Please try again.")
        }
    }
}
