//
//  PromptedTextEditor.swift
//  Compound
//
//  Created by Andrew Coyle on 04/03/2026.
//

import SwiftUI

struct PromptedTextEditor: View {
    
    @Binding var text: String
    let prompt: String?
    
    private var showPrompt: Bool {
        text.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
            
            if showPrompt, let prompt {
                Text(prompt)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            }
        }
        .frame(minHeight: 60)
    }
}

#Preview {
    @Previewable @State var text: String = ""
    let prompt: String = "Sample Prompt"
    List {
        PromptedTextEditor(text: $text, prompt: prompt)
    }
}
