//
//  ImageUploadService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/10/2025.
//

import SwiftUI

protocol ImageUploadService: Sendable {
    /// Scales the image so its longest side is at most `maxDimension` points and stores it as a
    /// JPEG at `quality`.
    func uploadImage(image: PlatformImage, path: String, maxDimension: CGFloat, quality: CGFloat) async throws -> URL
    func deleteImage(path: String) async throws
}

extension ImageUploadService {
    /// Profile pictures, food photos and thumbnails: 1280 points at JPEG 0.7.
    func uploadImage(image: PlatformImage, path: String) async throws -> URL {
        try await uploadImage(image: image, path: path, maxDimension: 1280, quality: 0.7)
    }
}
