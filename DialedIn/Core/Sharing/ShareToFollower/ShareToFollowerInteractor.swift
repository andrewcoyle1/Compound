//
//  ShareToFollowerInteractor.swift
//  DialedIn
//

@MainActor
protocol ShareToFollowerInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var followingUsers: [UserModel] { get }
    func sendShare(_ payload: ShareModel.Payload, to userIds: [String]) async throws
}

extension CoreInteractor: ShareToFollowerInteractor { }
