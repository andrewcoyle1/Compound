//
//  PeopleSearch.swift
//  Compound
//
//  Social's search field. People followed already are matched in memory and show at once; anyone
//  else waits on the network, so only that half has a spinner and a failure line.
//

import Foundation

@Observable
@MainActor
final class PeopleSearch {

    var query: String = ""

    private(set) var remoteUsers: [UserModel] = []

    /// Only the remote half waits on the network. The followed half shows at once.
    private(set) var isLoading: Bool = false

    /// The last remote search failed. Without it a network failure read as "no results".
    private(set) var failed: Bool = false

    private var task: Task<Void, Never>?
    private let followingUsers: () -> [UserModel]
    private let searchUsers: (String) async throws -> [UserModel]

    init(followingUsers: @escaping () -> [UserModel], searchUsers: @escaping (String) async throws -> [UserModel]) {
        self.followingUsers = followingUsers
        self.searchUsers = searchUsers
    }

    var isSearching: Bool {
        SearchMatch.isSearching(query)
    }

    /// Followed people first, then anyone the server found who is not already listed.
    var results: [UserModel] {
        let followed = followingUsers()
        let followedIds = Set(followed.map(\.userId))
        return (followed + remoteUsers.filter { !followedIds.contains($0.userId) })
            .filter { SearchMatch.matches(query, [$0.firstNameCalculated, $0.username]) }
    }

    /// Checks `results`, not `remoteUsers`: people the local filter rejects are not shown.
    var hasResults: Bool {
        !results.isEmpty || failed
    }

    func onQueryChanged() {
        task?.cancel()
        guard isSearching else {
            remoteUsers = []
            failed = false
            isLoading = false
            return
        }

        // Not normalised, which strips a leading `@`: that `@` is what routes a query to handles
        // only. See `Username.searchRoute`.
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Raised here, not in the task, so the spinner shows on the same tick. A task superseded by
        // a newer query leaves the flag to that query.
        isLoading = true
        task = Task {
            defer { if !Task.isCancelled { isLoading = false } }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            // No alert per keystroke: a failure shows as a line above the results instead.
            do {
                let users = try await searchUsers(query)
                guard !Task.isCancelled else { return }
                remoteUsers = users
                failed = false
            } catch {
                guard !Task.isCancelled else { return }
                remoteUsers = []
                failed = true
            }
        }
    }
}
