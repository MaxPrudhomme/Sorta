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
    private let maxToken: Int32 = 1024
    private var endMarker: String = ""
    
    init(model: String? = nil) {
        logger.info("Initializing Model")
        if let model = model {
            self.modelPath = model
        }
    }
    
    func generateResponseStream(to prompt: String, system: String, chunkHandler: @escaping (String) -> Void, completionHandler: @escaping (Error?) -> Void) async {
        do {
            print("Model : Checking model path")
            if modelPath.isEmpty { throw ModelError.modelNotFound }

            if llm == nil {
                llm = LLM(from: URL(fileURLWithPath: modelPath), temp: 0.6, maxTokenCount: maxToken)
                print("Model : Initialized LLM with model path \(modelPath)")
            }
            
            guard let llm = llm else {
                throw ModelError.modelNotInit
            }
            let userChat: Chat = (role: .user, content: prompt)

            let processed = llm.preprocess(prompt, history)
            
            print("Model : Starting response stream")
            await llm.respond(to: processed) { [self] stream in
                var fullResponse = ""
                let streamError: Error? = nil

                for await chunk in stream {
                    print("Model : Received chunk -> \(chunk)")
                    chunkHandler(chunk)
                    fullResponse += chunk
                }

                self.history.append(userChat)
                print("Model : Added user prompt to history")
                if !fullResponse.hasSuffix(endMarker) {
                    fullResponse += endMarker
                }
                
                self.history.append((role: .bot, content: fullResponse))
                print("Model : Added bot response to history")
                self.trimHistory()

                print("Model : Completed response stream")
                completionHandler(streamError)
                
                print("\n\n")
                print(history)
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
            "gemma-3-4b-it-q8_0.gguf",
            "deepseek-r1-distill-qwen-7b-q4_0.gguf",
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
