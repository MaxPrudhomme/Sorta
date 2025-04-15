//
//  LLM.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import SwiftUI
import LLM
import os

class Model {
    private var llm: LLM?
    private let logger = Logger(subsystem: "com.maxprudhomme.SortaHelper", category: "Model")
    private var modelSize: String = "small"
    
    init() {
        logger.info("[DEBUG] Initializing LLM model")
        
        if let modelPath = findBestAvailableModel() {
            logger.info("[DEBUG] Found model at path: \(modelPath)")
            
            let systemPrompt = """
            You are a helpful assistant that specializes in generating descriptive filenames.
            Follow these rules strictly:
            1. Focus on making the filename clear and descriptive of the file's content
            2. Always include the original file extension
            3. Use only letters, numbers, underscores, hyphens, and periods
            4. Keep filenames between 10-50 characters including extension
            5. For PDFs, extract key topics or document type from the content
            6. Never include invalid characters like quotes, colons, slashes, backslashes, question marks, percent signs, asterisks, pipes, or brackets
            7. NEVER include any explanations or chat markers, just the filename
            8. Use snake_case for multi-word filenames
            
            Examples of good filenames:

            """
            
            llm = LLM(from: URL(fileURLWithPath: modelPath), template: .chatML(systemPrompt), maxTokenCount: 256)
            
            if llm != nil {
                logger.info("[DEBUG] Successfully initialized LLM model")
            } else {
                logger.error("[DEBUG] Failed to initialize LLM model")
            }
        } else {
            logger.error("[DEBUG] Could not find any compatible model file")
        }
    }
    
    // Find the best available model in order of preference
    private func findBestAvailableModel() -> String? {
        let fileManager = FileManager.default
        let bundle = Bundle.main
        
        // Try to find larger models first (better quality)
        let modelOptions = [
            "llama-3.2-3b-Instruct_Q8-0.gguf",
        ]
        
        for modelName in modelOptions {
            // Check in the bundle first
            if let modelURL = bundle.url(forResource: modelName.components(separatedBy: ".").first, withExtension: "gguf") {
                if modelName.contains("7b") || modelName.contains("8b") {
                    modelSize = "large"
                } else if modelName.contains("3B") || modelName.contains("phi-2") {
                    modelSize = "medium"
                }
                return modelURL.path
            }
            
            // Also check in the app's Application Support directory for downloaded models
//            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
//                let bundleID = bundle.bundleIdentifier ?? "com.maxprudhomme.SortaHelper"
//                let modelsDirectory = appSupportURL.appendingPathComponent(bundleID).appendingPathComponent("Models")
//                let modelPath = modelsDirectory.appendingPathComponent(modelName).path
//                
//                if fileManager.fileExists(atPath: modelPath) {
//                    if modelName.contains("7b") || modelName.contains("8b") {
//                        modelSize = "large"
//                    } else if modelName.contains("4b") || modelName.contains("phi-2") {
//                        modelSize = "medium"
//                    }
//                    return modelPath
//                }
//            }
        }
        
        if let modelURL = bundle.url(forResource: "llama-3.2-3b-Instruct_Q8-0", withExtension: "gguf") {
            return modelURL.path
        }
        
        return nil
    }
    
    func respond(to prompt: String) async -> String {
        logger.info("[DEBUG] Sending prompt to LLM: \(prompt)")
        
        guard let llm = llm else {
            logger.error("[DEBUG] LLM not initialized")
            return ""
        }
        
        do {
            // Based on the minimal example from documentation:
            // let question = bot.preprocess("What's the meaning of life?", [])
            // let answer = await bot.getCompletion(from: question)
            let processedInput = llm.preprocess(prompt, [])
            logger.info("[DEBUG] Processed input: \(processedInput)")
            
            // This returns a String directly, not an AsyncSequence
            let result = await llm.getCompletion(from: processedInput)
            logger.info("[DEBUG] LLM raw response: \(result)")
            
            // Record detailed byte-by-byte information about the result
            let bytes = Array(result.utf8)
            logger.info("[DEBUG] Response bytes: \(bytes)")
            
            // Clean up the output to remove any ChatML markers
            let cleanedResult = cleanChatMLResponse(result)
            logger.info("[DEBUG] Cleaned LLM response: \(cleanedResult)")
            
            // If the model is too small and returning timestamp patterns, use heuristics
            if modelSize == "small" && (cleanedResult.isEmpty || cleanedResult.hasPrefix("file_") || isTimestampPattern(cleanedResult)) {
                logger.warning("[DEBUG] Small model detected returning generic pattern, using heuristics")
                let heuristicName = generateHeuristicName(from: prompt)
                logger.info("[DEBUG] Using heuristic name: \(heuristicName)")
                return heuristicName
            }
            
            // Final fallback - if the cleaned result is empty or invalid, return a simple timestamp-based name
            let finalResult = validateAndFixResult(cleanedResult)
            logger.info("[DEBUG] Final validated result: \(finalResult)")
            
            return finalResult
        } catch {
            logger.error("[DEBUG] Error getting LLM completion: \(error.localizedDescription)")
            return getFallbackFilename()
        }
    }
    
    // Detect if the string matches a timestamp pattern like "file_20250415_180201"
    private func isTimestampPattern(_ string: String) -> Bool {
        let timestampPattern = "^file_[0-9]{8}_[0-9]{6}$"
        let regex = try? NSRegularExpression(pattern: timestampPattern)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, range: range) != nil
    }
    
    // Generate a filename based on heuristics when the LLM fails to provide useful names
    private func generateHeuristicName(from prompt: String) -> String {
        var pdfContent = ""
        if let contentStartIndex = prompt.range(of: "Here is some content extracted from the file:")?.upperBound,
           let contentEndIndex = prompt.range(of: "Based on this content")?.lowerBound {
            pdfContent = String(prompt[contentStartIndex..<contentEndIndex])
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract original filename
        var originalFilename = ""
        if let filenameMatch = prompt.range(of: "File: \"(.+?)\"", options: .regularExpression) {
            originalFilename = String(prompt[filenameMatch])
                .replacingOccurrences(of: "File: \"", with: "")
                .replacingOccurrences(of: "\"", with: "")
        }
        
        // Extract file extension
        var fileExtension = ""
        if let extMatch = prompt.range(of: "original file extension is\\.(.+?)\\.", options: .regularExpression) {
            fileExtension = String(prompt[extMatch])
                .replacingOccurrences(of: "original file extension is.", with: "")
                .replacingOccurrences(of: ".", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let lastDotIndex = originalFilename.lastIndex(of: ".") {
            fileExtension = String(originalFilename[originalFilename.index(after: lastDotIndex)...])
        }
        
        // If we have PDF content, try to extract meaningful keywords
        if !pdfContent.isEmpty {
            let keywords = extractKeywords(from: pdfContent)
            if !keywords.isEmpty {
                let nameBase = keywords.joined(separator: "_").lowercased()
                return "\(nameBase).\(fileExtension)"
            }
        }
        
        // Extract date info if available
        var dateInfo = ""
        if let dateMatch = prompt.range(of: "Created: (.+?)(?:,|$)", options: .regularExpression) {
            let dateString = String(prompt[dateMatch])
                .replacingOccurrences(of: "Created: ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to extract just the date part
            if let datePart = dateString.split(separator: " at ").first {
                dateInfo = String(datePart)
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: ",", with: "")
            }
        }
        
        // Generate a filename with document type based on extension and date
        var docType = "document"
        if fileExtension == "pdf" {
            docType = "document"
        } else if ["jpg", "jpeg", "png", "gif"].contains(fileExtension.lowercased()) {
            docType = "image"
        } else if ["doc", "docx"].contains(fileExtension.lowercased()) {
            docType = "msword"
        } else if ["xls", "xlsx"].contains(fileExtension.lowercased()) {
            docType = "spreadsheet"
        } else if ["ppt", "pptx"].contains(fileExtension.lowercased()) {
            docType = "presentation"
        }
        
        // Create final name
        if !dateInfo.isEmpty {
            return "\(docType)_\(dateInfo).\(fileExtension)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let currentDate = dateFormatter.string(from: Date())
            return "\(docType)_\(currentDate).\(fileExtension)"
        }
    }
    
    // Extract meaningful keywords from text content
    private func extractKeywords(from text: String) -> [String] {
        // List of common stopwords to filter out
        let stopwords = ["the", "and", "a", "to", "of", "in", "that", "it", "with", "for", "as", "on", "at", "by", "from", "is", "was", "were", "be", "have", "has", "had", "this", "are", "not", "or", "but", "an", "which", "their", "they", "you", "your", "his", "her", "its", "our", "we", "all", "will", "can", "may", "would", "should", "could", "there", "than", "then", "when", "what", "who", "how", "no", "yes", "one", "two", "three"]
        
        // Clean the text
        let cleanText = text.lowercased()
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        
        // Split into words and filter out stopwords and short words
        let words = cleanText.split(separator: " ")
            .map { String($0) }
            .filter { !stopwords.contains($0) && $0.count > 3 }
        
        // Count word frequencies
        var wordFrequency: [String: Int] = [:]
        for word in words {
            wordFrequency[word, default: 0] += 1
        }
        
        // Get the most frequent words (up to 3)
        let sortedWords = wordFrequency.sorted { $0.value > $1.value }
        var keywords: [String] = []
        
        for (word, _) in sortedWords.prefix(3) {
            keywords.append(word)
        }
        
        // If we didn't get any meaningful keywords, use some generic ones based on the text length
        if keywords.isEmpty {
            if text.count > 1000 {
                keywords = ["detailed", "document"]
            } else if text.count > 500 {
                keywords = ["standard", "document"]
            } else {
                keywords = ["short", "document"]
            }
        }
        
        return keywords
    }
    
    // Clean up chatML markers and tokens from the output
    private func cleanChatMLResponse(_ response: String) -> String {
        var result = response
        
        logger.info("[DEBUG] cleanChatMLResponse input: \"\(response)\"")
        
        let patternsToRemove = [
            "im_start", "im_end",
            "user", "assistant",
            "?im_start", "?im_end",
            "<im_start>", "</im_start>",
            "<im_end>", "</im_end>",
            "<user>", "</user>",
            "<assistant>", "</assistant>",
            "The new filename is", "the new filename is",
            "New filename:", "new filename:",
            "Filename:", "filename:",
            "Here is a descriptive filename:", "Here's a descriptive filename:",
            "A good filename would be:", "A suitable filename would be:",
            "I suggest:", "I recommend:"
        ]
        
        for pattern in patternsToRemove {
            result = result.replacingOccurrences(of: pattern, with: "")
        }
        
        if let questionMarkRange = result.range(of: "?") {
            let startIndex = result.startIndex
            let endIndex = result.endIndex
            
            // Check if there's text before the question mark
            if startIndex < questionMarkRange.lowerBound {
                let textBeforeQuestionMark = result[startIndex..<questionMarkRange.lowerBound]
                // If there's non-alphanumeric text before the question mark, remove it
                if !textBeforeQuestionMark.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }) {
                    result.removeSubrange(startIndex..<questionMarkRange.upperBound)
                }
            }
            
            while result.last == "?" {
                result.removeLast()
            }
        }
        
        let explanationPhrases = [
            "Here's a descriptive filename:", 
            "I suggest:", 
            "A descriptive filename would be:",
            "Here's a suggestion:",
            "Based on the content, a good filename would be:",
            "For this file, I recommend:",
            "This file could be named:",
            "An appropriate name is:",
            "Given the content:",
            "A clear name would be:"
        ]
        
        for phrase in explanationPhrases {
            if let range = result.range(of: phrase) {
                result.removeSubrange(result.startIndex..<range.upperBound)
            }
        }
        
        result = result.replacingOccurrences(of: "\"", with: "")
        result = result.replacingOccurrences(of: "'", with: "")
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: "..", with: ".")
        
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.info("[DEBUG] cleanChatMLResponse output: \"\(result)\"")
        
        return result
    }
    
    private func validateAndFixResult(_ result: String) -> String {
        guard !result.isEmpty else {
            logger.warning("[DEBUG] Empty result after cleaning, using fallback")
            return getFallbackFilename()
        }
        
        // Check for invalid characters and remove them
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let cleanResult = result.components(separatedBy: invalidCharacters).joined()
        
        // If cleaning removed everything, return fallback
        guard !cleanResult.isEmpty else {
            logger.warning("[DEBUG] All characters were invalid, using fallback")
            return getFallbackFilename()
        }
        
        // If filename is too long, truncate it
        if cleanResult.count > 50 {
            let truncated = String(cleanResult.prefix(50))
            logger.info("[DEBUG] Truncated long filename from \(cleanResult.count) to 50 chars")
            return truncated
        }
        
        // If filename is too short (less than 5 chars excluding extension), use fallback
        let components = cleanResult.components(separatedBy: ".")
        if components.count > 1 {
            let nameWithoutExtension = components.dropLast().joined(separator: ".")
            if nameWithoutExtension.count < 5 {
                logger.warning("[DEBUG] Filename too short, using fallback")
                return getFallbackFilename()
            }
        }
        
        return cleanResult
    }
    
    // Generate a simple timestamp-based fallback filename
    private func getFallbackFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        return "file_\(dateFormatter.string(from: Date()))"
    }
}
