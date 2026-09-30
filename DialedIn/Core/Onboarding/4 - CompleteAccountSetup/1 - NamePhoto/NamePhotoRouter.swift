//
//  NamePhotoRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NamePhotoRouter: GlobalRouter {
    func showGenderView()
}

extension CoreRouter: NamePhotoRouter { }
