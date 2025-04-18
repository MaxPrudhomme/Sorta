//
//  Model.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation
import LLM
import os

class Model {
    private var llm: LLM?
    private var modelPath: String = Model.findModel() ?? ""
    private let logger = Logger(subsystem: "com.maxprudhomme.sortadaemon", category: "Model")

    private var history: [Chat] = []
    private var historyLimit: Int = 10
    
    init(model: String? = nil) {
        logger.info("Initializing Model")
        if let model = model {
            self.modelPath = model
        }
    }

    func generateResponse(to prompt: String, system: String) async throws -> String {
        if modelPath.isEmpty { throw ModelError.modelNotFound }
        
        if llm == nil {
            llm = LLM(from: URL(fileURLWithPath: modelPath), template: .chatML(system), maxTokenCount: 512)
        }
        
        guard let llm = llm else { throw ModelError.modelNotInit }

        history.append((role: .user, content: prompt))
        
        let processed = llm.preprocess(prompt, history)
        let response = await llm.getCompletion(from: processed)
        
        if response.isEmpty {
            throw ModelError.generationError
        }
        
        history.append((role: .bot, content: response))
        
        if historyLimit * 2 < history.count {
            history.removeFirst(2)
        }
        
        return response
    }
    
    func generateResponseStream(to prompt: String, system: String, chunkHandler: @escaping (String) -> Void, completionHandler: @escaping (Error?) -> Void) async {
        do {
            if modelPath.isEmpty { throw ModelError.modelNotFound }
            logger.info("Model path found: \(self.modelPath, privacy: .public)")

            if llm == nil {
                llm = LLM(from: URL(fileURLWithPath: modelPath), template: .chatML(system), maxTokenCount: 512)
                logger.info("LLM initialized with template: chatML(system)")
            }
            
            guard let llm = llm else {
                throw ModelError.modelNotInit
            }
            let userChat: Chat = (role: .user, content: prompt)

            let processed = llm.preprocess(prompt, history)
            
            logger.info("Beginning streaming response")
            await llm.respond(to: processed) { stream in
                var fullResponse = ""
                var streamError: Error? = nil

                do {
                    for try await chunk in stream {
                    chunkHandler(chunk)
                        self.logger.debug("Received chunk: \(chunk, privacy: .public)")
                    fullResponse += chunk
                    }
                } catch {
                    streamError = error
                }

                if streamError == nil {
                    self.history.append(userChat)
                    self.history.append((role: .bot, content: fullResponse))
                    self.trimHistory()
                }

                self.logger.info("Streaming response complete. Error: \(String(describing: streamError), privacy: .public)")
                completionHandler(streamError)
                return fullResponse
            }

        } catch {
            completionHandler(error)
        }
    }

    private func trimHistory() {
        let maxEntries = historyLimit * 2
        if history.count > maxEntries {
            let entriesToRemove = history.count - maxEntries
            history.removeFirst(entriesToRemove)
            logger.info("Trimmed history, removed \(entriesToRemove) entries.")
        }
    }
    
    static func findModel() -> String? {
        let fileManager = FileManager.default
        let modelDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let modelOptions = [
            "mistral-7b-instruct-v0.3-q4_k_m.gguf",
            "mistral-7b-instruct-v0.3-q8_0.gguf",
            "llama-3.2-3b-q8_0.gguf"
        ]

        for modelName in modelOptions {
            let modelURL = modelDirectory.appendingPathComponent(modelName)
            if fileManager.fileExists(atPath: modelURL.path) {
                return modelURL.path
            }
        }

        return nil
    }

    enum ModelError: Error {
        case modelNotFound
        case modelNotInit
        case generationError
    }
}
