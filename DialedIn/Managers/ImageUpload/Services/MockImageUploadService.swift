//
//  MockImageUploadService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/10/2025.
//

import SwiftUI
struct MockImageUploadService: ImageUploadService {
    func uploadImage(image: PlatformImage, path: String, maxDimension: CGFloat, quality: CGFloat) async throws -> URL {
        URL(string: "https://example.com/image.png")!
    }
    
    func deleteImage(path: String) async throws {
        // No-op for mock
    }
}
