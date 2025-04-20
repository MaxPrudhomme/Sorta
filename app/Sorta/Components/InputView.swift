//
//  InputView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 19/04/2025.
//

import SwiftUI

struct InputView: View {
    @Binding var inputText: String
    var isGeneratingResponse: Bool
    var sendAction: () -> Void

    var body: some View {
        HStack {
            TextField("Enter message...", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: sendAction) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(isGeneratingResponse || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}
