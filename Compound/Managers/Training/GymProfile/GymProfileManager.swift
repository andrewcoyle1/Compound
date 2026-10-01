//
//  GymProfileManager.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

@Observable
@MainActor
class GymProfileManager {
    
    private let gymProfileSyncEngine: CollectionSyncEngine<GymProfileModel>
        
    var gymProfiles: [GymProfileModel] {
        gymProfileSyncEngine.currentCollection
    }

    var activeWorkoutGymProfile: GymProfileModel?

    init(gymProfileSyncEngine: CollectionSyncEngine<GymProfileModel>) {
        self.gymProfileSyncEngine = gymProfileSyncEngine
    }
    
    func signIn() async {
        await gymProfileSyncEngine.startListening()
    }
    
    func signOut() {
        gymProfileSyncEngine.stopListening()
        // Held here rather than in the sync engine, so stopping the listener does not clear it.
        // Left set, it is the previous account's gym, and the next sign-in reads it as the
        // current user's own.
        activeWorkoutGymProfile = nil
    }

    // MARK: WRITE
    
    func saveGymProfile(profile: GymProfileModel, image: PlatformImage?) async throws {
        var profile = profile
        if let image {
            let path = "users/\(profile.authorId)/gymProfiles/\(profile.id)"
            let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
            profile.updateImageUrl(imageUrl: url.absoluteString)
        }
        try await gymProfileSyncEngine.saveDocument(profile)
    }
        
    // MARK: READ
    
    func getGymProfile(gymProfileId: String) async throws -> GymProfileModel {
        try await gymProfileSyncEngine.getDocumentAsync(id: gymProfileId)
    }
    
    // MARK: DELETE
        
    func deleteGymProfile(_ profileId: String) async throws {
        try await gymProfileSyncEngine.deleteDocument(id: profileId)
        // A workout in progress filters exercises on the active gym's equipment. Leaving a
        // deleted gym selected keeps filtering on equipment that no longer exists.
        if activeWorkoutGymProfile?.id == profileId {
            activeWorkoutGymProfile = nil
        }
    }
    
    func deleteAllGymProfiles() async throws {
        for profile in gymProfiles {
            try await deleteGymProfile(profile.id)
        }
    }

}

extension CoreInteractor {
    
    // MARK: GymProfileManager
    
    var gymProfiles: [GymProfileModel] {
        gymProfileManager.gymProfiles
    }
    
    var favouriteGymProfile: GymProfileModel? {
        guard let favouriteGymProfileId = currentUser?.submittedFavouriteGymProfileId else { return nil }
        return gymProfiles.first { model in
            model.id == favouriteGymProfileId
        }
    }

    var workoutGymProfile: GymProfileModel? {
        gymProfileManager.activeWorkoutGymProfile ?? favouriteGymProfile
    }

    func setActiveWorkoutGymProfile(_ profile: GymProfileModel?) {
        gymProfileManager.activeWorkoutGymProfile = profile
    }

    func getGymProfile(gymProfileId: String) async throws -> GymProfileModel {
        try await gymProfileManager.getGymProfile(gymProfileId: gymProfileId)
    }

    func saveGymProfile(profile: GymProfileModel, image: PlatformImage?) async throws {
        try await gymProfileManager.saveGymProfile(profile: profile, image: image)
    }

    func deleteGymProfile(_ profileId: String) async throws {
        try await gymProfileManager.deleteGymProfile(profileId)
    }

}
