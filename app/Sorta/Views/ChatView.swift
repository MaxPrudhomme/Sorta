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
                                .id(message.id)
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
            InputView(inputText: $vm.inputText, isGeneratingResponse: vm.isGeneratingResponse, sendAction: { vm.streamMessage() })
        }
        .alert(item: $vm.errorMessage) { errorMessage in
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    private let client: DaemonClient
    private var state: Bool = false
    
    private var listener: NSXPCListener?
    
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isGeneratingResponse: Bool = false
    @Published var errorMessage: String? = nil

    private var currentAssistantMessageId: UUID? = nil
    private let stopSequence = "<|im_end|>"
    
    init(client: DaemonClient) {
        self.client = client
    }
    
    func streamMessage() {
        print("\n \n ChatView : Starting a new stream")
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let userMessage = Message(sender: .user, content: trimmedInput)
        messages.append(userMessage)
        inputText = ""

        isGeneratingResponse = true

        let assistantMessage = Message(sender: .assistant, content: "...")
        messages.append(assistantMessage)
        currentAssistantMessageId = assistantMessage.id
        var firstChunkReceived = false

        client.generateResponseStreaming(
            prompt: trimmedInput,
            chunkHandler: { [weak self] chunk in
                guard let self = self,
                    let id = self.currentAssistantMessageId
                else { return }

                if let index = self.messages.firstIndex(where: { $0.id == id })
                {
                    if !firstChunkReceived {
                        self.messages[index].content = ""
                        firstChunkReceived = true
                    }
                    self.messages[index].content += chunk
                } else {
                    print("ViewModel Error: Could not find assistant message with ID \(id) to append chunk.")
                }
            },
            completionHandler: { [weak self] error in
                DispatchQueue.main.async {
                    print("Completion handler")
                    self?.isGeneratingResponse = false

                    if let error = error {
                        if let id = self?.currentAssistantMessageId,
                           let index = self?.messages.firstIndex(where: { $0.id == id }) {
                            self?.messages[index].content = "Error: \(error.localizedDescription)"
                        }
                    } else {
                        if let id = self?.currentAssistantMessageId,
                           let index = self?.messages.firstIndex(where: { $0.id == id }),
                           self?.messages[index].content.isEmpty == true {
                            self?.messages[index].content = "(No response)"
                        }
                    }
                    self?.currentAssistantMessageId = nil
                }
            }
        )
    }
}
