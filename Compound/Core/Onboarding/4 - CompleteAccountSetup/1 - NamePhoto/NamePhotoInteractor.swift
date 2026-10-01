//
//  NamePhotoInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NamePhotoInteractor {
    var currentUser: UserModel? { get }
    func updateUserName(firstName: String?, lastName: String?) async throws 
    func updateProfileImageUrl(image: PlatformImage) async throws
    func trackEvent(event: LoggableEvent)
}

extension CoreInteractor: NamePhotoInteractor { }
