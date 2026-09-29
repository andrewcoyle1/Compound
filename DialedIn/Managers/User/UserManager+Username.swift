//
//  UserManager+Username.swift
//  DialedIn
//
//  Claiming a handle is two writes: the reservation `usernames/{handle}`, which rules only let one
//  user create, then the `username` field on the user's own document, which rules only accept for
//  a handle the writer holds. The `onUsernameChanged` Cloud Function releases the old reservation.
//

import Foundation

extension UserManager {

    /// Free, or already the reader's. An invalid handle is never available.
    func isUsernameAvailable(_ raw: String) async throws -> Bool {
        let handle = Username.normalised(raw)
        guard Username.isValid(handle) else { return false }
        let owner = try await usernameQueryService.usernameOwner(handle)
        return owner == nil || owner == currentUser?.userId
    }

    /// Reserves `raw` and sets it on the reader's profile. Throws `UsernameError.taken` when the
    /// reservation belongs to someone else or cannot be written (someone got there first).
    func claimUsername(_ raw: String) async throws {
        guard let userId = currentUser?.userId else { throw UserManagerError.noUserId }
        let handle = Username.normalised(raw)
        guard Username.isValid(handle) else { throw UsernameError.invalid }
        guard handle != currentUser?.username else { return }

        switch try await usernameQueryService.usernameOwner(handle) {
        case nil:
            do {
                try await usernameQueryService.reserveUsername(handle, userId: userId)
            } catch {
                throw UsernameError.taken
            }
        case userId:
            // Reserved on an earlier attempt whose profile write failed; finish that claim.
            break
        default:
            throw UsernameError.taken
        }
        try await updateUser(data: [UserModel.CodingKeys.username.rawValue: handle])
    }

    /// Name search plus handle-prefix search, routed by `Username.searchRoute`. Handle matches come
    /// first, and anyone found both ways appears once.
    func searchUsersByNameOrHandle(query: String) async throws -> [UserModel] {
        let route = Username.searchRoute(for: query)
        var results: [UserModel] = []
        if let prefix = route.handlePrefix {
            results += try await usernameQueryService.searchUsers(usernamePrefix: prefix)
        }
        if let name = route.name {
            results += try await searchUsers(query: name)
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.userId).inserted && !(currentUser?.hasBlocked($0.userId) ?? false) }
    }
}
