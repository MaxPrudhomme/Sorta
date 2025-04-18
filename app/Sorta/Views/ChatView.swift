//
//  ChatView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation
import SwiftUI


struct ChatView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        VStack {
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            MessageView(message: message)
                                .id(message.id) // Assign ID for scrolling
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: vm.messages.count) { oldValue, newValue in
                        if let lastMessage = vm.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            HStack {
                TextField("Enter message...", text: $vm.inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(vm.isGeneratingResponse) // Disable input while waiting for response

                if vm.isGeneratingResponse {
                    ProgressView()
                } else {
                    Button {
                        vm.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Disable send button for empty input
                }
            }
            .padding()
        }
        .navigationTitle("LLM Chat")
         // Optional: Display error as an alert
        .alert(item: $vm.errorMessage) { errorMessage in
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
}
@MainActor
class ChatViewModel: ObservableObject {
    private let client: DaemonClient

    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isGeneratingResponse: Bool = false
    @Published var errorMessage: String? = nil

    init(client: DaemonClient) {
        self.client = client
        self.client.connect()
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return // Don't send empty messages
        }

        let userMessageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = Message(sender: .user, content: userMessageContent)

        // Add the user message immediately to the display
        messages.append(userMessage)
        inputText = "" // Clear the input field

        isGeneratingResponse = true
        errorMessage = nil // Clear any previous error

        // Call the daemon client
        client.generateResponse(prompt: userMessageContent) { [weak self] response, error in
            guard let self = self else { return }

            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                self.isGeneratingResponse = false

                if let error = error {
                    // Handle error
                    let errorMessageContent = "Error: \(error.localizedDescription)"
                    let errorMessage = Message(sender: .assistant, content: errorMessageContent)
                    self.messages.append(errorMessage) // Or handle errors differently, like an alert
                    self.errorMessage = errorMessageContent // Store error for potential alert
                    print("Daemon response error: \(error)")
                } else if let response = response, !response.isEmpty {
                    // Add assistant's response
                    let assistantMessage = Message(sender: .assistant, content: response)
                    self.messages.append(assistantMessage)
                } else {
                    // Handle empty response if no error occurred
                     let noResponseMessage = Message(sender: .assistant, content: "Received empty response from daemon.")
                     self.messages.append(noResponseMessage)
                     print("Daemon returned empty response with no error.")
                }
            }
        }
    }
}
