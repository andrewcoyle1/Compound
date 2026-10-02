//
//  DeleteAccountInteractor.swift
//  Compound
//

@MainActor
protocol DeleteAccountInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    func deleteAccount() async throws
}

extension CoreInteractor: DeleteAccountInteractor { }
