//
//  CoreInteractor+Username.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    func isUsernameAvailable(_ handle: String) async throws -> Bool {
        try await userManager.isUsernameAvailable(handle)
    }

    func claimUsername(_ handle: String) async throws {
        try await userManager.claimUsername(handle)
    }
}
