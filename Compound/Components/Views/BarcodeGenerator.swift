//
//  BarcodeGenerator.swift
//  Compound
//
//  Created by Andrew Coyle on 04/03/2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct BarcodeGenerator {
    let context = CIContext()

    func generateBarcode(text: String) -> Image {
        let generator = CIFilter.code128BarcodeGenerator()
        generator.message = Data(text.utf8)

        if let outputImage = generator.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            return Image(uiImage: uiImage)
        }

        return Image(systemName: "barcode")
    }
}
