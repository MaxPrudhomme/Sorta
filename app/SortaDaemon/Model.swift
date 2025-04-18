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

    
    init(model: String? = nil) {
        logger.info("Initializing Model")
        if let model = model {
            self.modelPath = model
        }
    }

    func generateResponse(to prompt: String, system: String) async throws -> String {
        if modelPath.isEmpty { throw ModelError.modelNotFound }
        
        llm = LLM(from: URL(fileURLWithPath: modelPath), template: .chatML(system), maxTokenCount: 4096)
        
        guard let llm = llm else { throw ModelError.modelNotInit }

        let processed = llm.preprocess(prompt, [])
        let response = await llm.getCompletion(from: processed)
        
        if response.isEmpty {
            throw ModelError.generationError
        }
        
        return response
    }
    
    static func findModel() -> String? {
        let fileManager = FileManager.default
        let modelDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let modelOptions = [
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
