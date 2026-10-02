//
//  ExerciseImageView.swift
//  Compound
//
//  An exercise's picture, or its initials (at most two) on a secondary fill when it has none.
//

import SwiftUI

struct ExerciseImageView: View {

    let name: String
    let imageName: String?
    var resizingMode: ContentMode = .fit
    var clipShape: AnyShape = AnyShape(.rect(cornerRadius: Radius.s, style: .continuous))

    var body: some View {
        if let imageName, !imageName.isEmpty {
            ImageLoaderView(urlString: imageName, resizingMode: resizingMode, clipShape: clipShape)
        } else {
            clipShape
                .fill(.secondary)
                .overlay {
                    Text(Self.initials(of: name))
                        .font(.sectionTitle)
                        .foregroundStyle(.background)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .padding(Spacing.xxs)
                }
                .accessibilityHidden(true)
        }
    }

    /// "Barbell Bench Press" → "BB", "plank" → "P".
    static func initials(of name: String) -> String {
        String(name.split(separator: " ").compactMap(\.first).filter(\.isLetter).prefix(2)).uppercased()
    }
}

#Preview {
    HStack {
        ExerciseImageView(name: "Barbell Bench Press", imageName: nil)
            .frame(width: 60, height: 60)
        ExerciseImageView(name: "Plank", imageName: nil, clipShape: AnyShape(Circle()))
            .frame(width: 60, height: 60)
        ExerciseImageView(name: "Barbell Squat", imageName: "BarbellSquat")
            .frame(width: 60, height: 60)
    }
}
