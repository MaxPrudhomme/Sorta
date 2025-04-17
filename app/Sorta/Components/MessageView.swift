//
//  MessageView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation
import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }

            Text(message.content)
                .padding(10)
                .background(message.sender == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.sender == .user ? .white : .primary)
                .cornerRadius(10)

            if message.sender == .assistant {
                Spacer()
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String {
        self
    }
}

struct Message: Identifiable {
    let id = UUID()
    let sender: Sender
    let content: String
}

enum Sender {
    case user
    case assistant
}
