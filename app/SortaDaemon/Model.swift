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
    
    func generateResponseStream(to prompt: String, system: String, chunkHandler: @escaping (String) -> Void, completionHandler: @escaping (Error?) -> Void) async {
        do {
            if modelPath.isEmpty { throw ModelError.modelNotFound }

            if llm == nil {
                llm = LLM(from: URL(fileURLWithPath: modelPath), template: .chatML(system), maxTokenCount: 8192)
            }
            
            guard let llm = llm else {
                throw ModelError.modelNotInit
            }
            let userChat: Chat = (role: .user, content: prompt)

            let processed = llm.preprocess(prompt, history)
            
            await llm.respond(to: processed) { stream in
                var fullResponse = ""
                let streamError: Error? = nil

                for await chunk in stream {
                    chunkHandler(chunk)
                    fullResponse += chunk
                }

                self.history.append(userChat)
                self.history.append((role: .bot, content: fullResponse))
                self.trimHistory()

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
            "deepseek-r1-distill-qwen-7b-q4_0.gguf",
            "mistral-7b-instruct-v0.3-q4_k_m.gguf",
            "mistral-7b-instruct-v0.3-q8_0.gguf",
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
