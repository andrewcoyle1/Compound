//
//  CoreInteractor+ScheduledPush.swift
//  DialedIn
//

extension CoreInteractor {
    func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws {
        try await userManager.updatePrivateSettings(change)
    }
}
