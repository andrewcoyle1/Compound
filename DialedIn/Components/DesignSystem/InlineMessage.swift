//
//  InlineMessage.swift
//  DialedIn
//

import SwiftUI

/// A one-line status message inside a form, sheet or scanner: a symbol and text in the kind's
/// colour, read by VoiceOver as one element ("Error, …"). Use it in place of raw red or orange
/// `Text`.
struct InlineMessage: View {

    enum Kind {
        case error, warning, info

        var symbol: String {
            switch self {
            case .error: return Symbol.error
            case .warning: return Symbol.warning
            case .info: return Symbol.info
            }
        }

        var color: Color {
            switch self {
            case .error: return .danger
            case .warning: return .warning
            case .info: return .secondary
            }
        }

        var accessibilityName: Text {
            switch self {
            case .error: return Text("Error")
            case .warning: return Text("Warning")
            case .info: return Text("Info")
            }
        }
    }

    let kind: Kind
    let text: Text

    init(_ kind: Kind, _ text: LocalizedStringKey) {
        self.kind = kind
        self.text = Text(text)
    }

    /// For runtime strings such as `error.localizedDescription`, which are not localisation keys.
    @_disfavoredOverload
    init<S: StringProtocol>(_ kind: Kind, _ text: S) {
        self.kind = kind
        self.text = Text(text)
    }

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: kind.symbol)
                .accessibilityLabel(kind.accessibilityName)
        }
        .font(.rowDetail)
        .foregroundStyle(kind.color)
        .accessibilityElement(children: .combine)
    }
}

private struct InlineMessagePreview: View {
    var body: some View {
        List {
            Section {
                Text("Barcode")
                InlineMessage(.error, "We couldn't find that barcode. Try again or search by name.")
                InlineMessage(.warning, "This food has no serving size, so amounts are in grams.")
                InlineMessage(.info, "Values are per 100 g.")
            }
        }
    }
}

#Preview("Light") {
    InlineMessagePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    InlineMessagePreview().preferredColorScheme(.dark)
}

#Preview("Accessibility size") {
    InlineMessagePreview().dynamicTypeSize(.accessibility3)
}
