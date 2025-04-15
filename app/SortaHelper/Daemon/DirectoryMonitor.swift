//
//  DirectoryMonitor.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import Combine
import SwiftUI
import LLM
import PDFKit

class DirectoryMonitor {
    private var fileDescriptor: CInt = -1
    private let queue = DispatchQueue(label: "com.maxprudhomme.directorymonitor", attributes: .concurrent)
    private var source: DispatchSourceFileSystemObject?
    private let logger = Logger(subsystem: "com.maxprudhomme.SortaHelper", category: "DirectoryMonitor")
    
    private var processingTimer: Timer?
    private let processingInterval: TimeInterval = 2.0
    
    private var knownFiles: Set<String> = []
    private var llmModel: Model
    
    // File logging properties
    private let fileLogger: FileLogger
    private let logsDirectory: URL
    
    let path: String
    
    init(path: String) {
        self.path = path
        self.llmModel = Model()
        
        // Initialize file logger
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.maxprudhomme.SortaHelper"
        self.logsDirectory = appSupportURL.appendingPathComponent(bundleID).appendingPathComponent("Logs")
        
        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
        
        self.fileLogger = FileLogger(directory: logsDirectory)
        
        fileLogger.log("DirectoryMonitor initialized for path: \(path)")
        logger.info("[DEBUG] DirectoryMonitor initialized for path: \(path)")
        print("[DEBUG] DirectoryMonitor initialized for path: \(path)")
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        if source != nil {
            return
        }
        
        fileDescriptor = open(path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            logger.error("[DEBUG] Failed to open directory at path: \(self.path)")
            print("[DEBUG] Failed to open directory at path: \(self.path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .attrib, .extend, .link, .delete, .revoke],
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.logger.info("[DEBUG] Detected changes in monitored directory: \(self.path)")
            self.fileLogger.log("Detected changes in monitored directory: \(self.path)")
            print("[DEBUG] Detected changes in monitored directory: \(self.path)")
            
            DispatchQueue.main.async {
                self.processingTimer?.invalidate()
                self.processingTimer = Timer.scheduledTimer(withTimeInterval: self.processingInterval, repeats: false) { _ in
                    self.processFiles()
                }
            }
        }
        
        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
            self.logger.info("[DEBUG] Directory monitoring stopped")
            print("[DEBUG] Directory monitoring stopped")
        }
        
        source?.resume()
        logger.info("[DEBUG] Directory monitoring started for: \(self.path)")
        fileLogger.log("Directory monitoring started for: \(self.path)")
        print("[DEBUG] Directory monitoring started for: \(self.path)")
        
        processFiles() // Process existing files when starting monitoring
    }
    
    func stopMonitoring() {
        processingTimer?.invalidate()
        processingTimer = nil
        source?.cancel()
        source = nil
        logger.info("[DEBUG] Monitoring stopped for path: \(self.path)")
        fileLogger.log("Monitoring stopped for path: \(self.path)")
        print("[DEBUG] Monitoring stopped for path: \(self.path)")
    }
    
    private func processFiles() {
        logger.info("[DEBUG] Processing files in: \(self.path)")
        fileLogger.log("Processing files in: \(self.path)")
        print("[DEBUG] Processing files in: \(self.path)")
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: self.path)
            logger.info("[DEBUG] Files found: \(files.count)")
            fileLogger.log("Files found: \(files.count)")
            print("[DEBUG] Files found: \(files.count)")
            
            Task {
                for file in files where !file.hasPrefix(".") {
                    do {
                        let filePath = (self.path as NSString).appendingPathComponent(file)
                        var isDirectory: ObjCBool = false
                        
                        // Check if file exists and is not a directory
                        guard fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory), !isDirectory.boolValue else {
                            if isDirectory.boolValue {
                                self.logger.info("[DEBUG] Skipping directory: \(filePath)")
                                self.fileLogger.log("Skipping directory: \(filePath)")
                                print("[DEBUG] Skipping directory: \(filePath)")
                            } else {
                                self.logger.error("[DEBUG] File does not exist: \(filePath)")
                                self.fileLogger.log("ERROR: File does not exist: \(filePath)")
                                print("[DEBUG] File does not exist: \(filePath)")
                            }
                            continue
                        }
                        
                        // Skip already processed files
                        if self.knownFiles.contains(file) {
                            self.logger.info("[DEBUG] File already known: \(file)")
                            self.fileLogger.log("File already known: \(file)")
                            print("[DEBUG] File already known: \(file)")
                            continue
                        }
                        
                        self.logger.info("[DEBUG] New file detected: \(file)")
                        self.fileLogger.log("New file detected: \(file)")
                        print("[DEBUG] New file detected: \(file)")
                        
                        // Check file access permissions
                        guard fileManager.isWritableFile(atPath: filePath) else {
                            self.logger.error("[DEBUG] File is not writable: \(filePath)")
                            self.fileLogger.log("ERROR: File is not writable: \(filePath)")
                            print("[DEBUG] File is not writable: \(filePath)")
                            self.knownFiles.insert(file)
                            continue
                        }
                        
                        // Make a local backup of the file before renaming
                        let backupPath = filePath + ".backup"
                        try? fileManager.copyItem(atPath: filePath, toPath: backupPath)
                        self.fileLogger.log("Created backup at: \(backupPath)")
                        
                        // Get file extension and file size for better context
                        let fileExtension = (file as NSString).pathExtension
                        let fileAttributes = try? fileManager.attributesOfItem(atPath: filePath)
                        let fileSize = fileAttributes?[.size] as? Int64 ?? 0
                        let creationDate = fileAttributes?[.creationDate] as? Date
                        let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                        let fileSizeKB = Double(fileSize) / 1024.0
                        
                        // Create a better prompt with more context about the file
                        var promptDetails = "File: \"\(file)\", Size: \(fileSizeString)"
                        if let creationDate = creationDate {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            promptDetails += ", Created: \(formatter.string(from: creationDate))"
                        }
                        
                        // Extract content from PDF files to provide better context
                        var fileContent = ""
                        if fileExtension.lowercased() == "pdf" {
                            fileContent = extractPDFContent(filePath: filePath)
                            if !fileContent.isEmpty {
                                self.fileLogger.log("Extracted \(fileContent.count) characters from PDF")
                                
                                // Truncate content to avoid overwhelming the LLM
                                let maxContentLength = 500
                                if fileContent.count > maxContentLength {
                                    fileContent = String(fileContent.prefix(maxContentLength)) + "..."
                                }
                            } else {
                                self.fileLogger.log("Could not extract content from PDF")
                            }
                        }
                        
                        let prompt: String
                        if !fileContent.isEmpty {
                            prompt = """
                            Suggest a descriptive filename for this file. \(promptDetails).
                            The original file extension is .\(fileExtension).
                            
                            Here is some content extracted from the file:
                            "\(fileContent)"
                            
                            Based on this content and file information, provide a descriptive filename that reflects what the file contains.
                            Only respond with the new filename including the extension.
                            """
                        } else {
                            prompt = """
                            Suggest a descriptive filename for this file. \(promptDetails).
                            The original file extension is .\(fileExtension).
                            Focus on making the name descriptive of what the file might contain based on its name and size.
                            Only respond with the new filename including the extension.
                            """
                        }
                        
                        self.logger.info("[DEBUG] Prompting LLM for new name. Details: \(promptDetails)")
                        self.fileLogger.log("Prompting LLM for new name. Details: \(promptDetails)")
                        print("[DEBUG] Prompting LLM for new name. Details: \(promptDetails)")
                        
                        // Get suggestion from LLM
                        let suggestion = await self.llmModel.respond(to: prompt)
                        var newName = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)

                        // Log raw suggestion
                        self.logger.info("[DEBUG] Raw LLM suggestion: \"\(newName)\"")
                        self.fileLogger.log("Raw LLM suggestion: \"\(newName)\"")
                        print("[DEBUG] Raw LLM suggestion: \"\(newName)\"")
                        
                        // Detailed logging of exactly what the LLM returned, character by character
                        self.fileLogger.log("--- DETAILED LLM OUTPUT START ---")
                        self.fileLogger.log("Character count: \(suggestion.count)")
                        self.fileLogger.log("Raw bytes: \(Array(suggestion.utf8))")
                        let charByChar = suggestion.map { "'\($0)' (Unicode: \(String($0).unicodeScalars.first?.value ?? 0))" }.joined(separator: ", ")
                        self.fileLogger.log("Characters: \(charByChar)")
                        self.fileLogger.log("--- DETAILED LLM OUTPUT END ---")
                        
                        // Sanitize the filename
                        newName = self.sanitizeFilename(newName, originalExtension: fileExtension)
                        
                        // Add size information to filenames
                        if !fileExtension.isEmpty && fileSizeKB > 0 {
                            // Insert size info before extension
                            let sizeStr = "\(Int(fileSizeKB))kb"
                            let baseName = (newName as NSString).deletingPathExtension
                            newName = "\(baseName)_\(sizeStr).\(fileExtension)"
                            self.fileLogger.log("Added size information: \(newName)")
                        }
                        
                        // Validate the sanitized name
                        if newName.isEmpty || newName.count > 255 {
                            self.logger.error("[DEBUG] LLM suggested invalid name after sanitization: \"\(newName)\", using fallback")
                            self.fileLogger.log("ERROR: LLM suggested invalid name after sanitization: \"\(newName)\", using fallback")
                            print("[DEBUG] LLM suggested invalid name after sanitization: \"\(newName)\", using fallback")
                            
                            // Create a fallback name with timestamp and size info
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                            newName = "file_\(dateFormatter.string(from: Date()))_\(Int(fileSizeKB))kb.\(fileExtension)"
                            self.fileLogger.log("Using fallback name: \(newName)")
                        }
                        
                        // Ensure the extension is preserved
                        if !fileExtension.isEmpty && !(newName as NSString).pathExtension.lowercased().contains(fileExtension.lowercased()) {
                            newName = (newName as NSString).deletingPathExtension + "." + fileExtension
                            self.logger.info("[DEBUG] Fixed extension in suggested name: \(newName)")
                            self.fileLogger.log("Fixed extension in suggested name: \(newName)")
                            print("[DEBUG] Fixed extension in suggested name: \(newName)")
                        }
                        
                        self.logger.info("[DEBUG] LLM suggested name: \"\(newName)\"")
                        self.fileLogger.log("LLM suggested name: \"\(newName)\"")
                        print("[DEBUG] LLM suggested name: \"\(newName)\"")
                        
                        // Skip if suggested name is the same as original
                        if newName == file {
                            self.logger.info("[DEBUG] LLM suggested same name as original, skipping rename")
                            self.fileLogger.log("LLM suggested same name as original, skipping rename")
                            print("[DEBUG] LLM suggested same name as original, skipping rename")
                            self.knownFiles.insert(file)
                            try? fileManager.removeItem(atPath: backupPath) // Remove backup since no change
                            continue
                        }
                        
                        let newFilePath = (self.path as NSString).appendingPathComponent(newName)
                        
                        // Check if a file with the new name already exists
                        if fileManager.fileExists(atPath: newFilePath) {
                            self.logger.info("[DEBUG] File with suggested name already exists: \(newFilePath)")
                            self.fileLogger.log("File with suggested name already exists: \(newFilePath)")
                            print("[DEBUG] File with suggested name already exists: \(newFilePath)")
                            
                            // Modify name to make it unique
                            let timestamp = Int(Date().timeIntervalSince1970)
                            let uniqueNewName = "\((newName as NSString).deletingPathExtension)_\(timestamp).\(fileExtension)"
                            let uniqueNewPath = (self.path as NSString).appendingPathComponent(uniqueNewName)
                            
                            self.logger.info("[DEBUG] Using unique name instead: \(uniqueNewName)")
                            self.fileLogger.log("Using unique name instead: \(uniqueNewName)")
                            print("[DEBUG] Using unique name instead: \(uniqueNewName)")
                            
                            // Try to rename with the unique name
                            do {
                                try fileManager.moveItem(atPath: filePath, toPath: uniqueNewPath)
                                self.logger.info("[DEBUG] Successfully renamed \(file) to \(uniqueNewName)")
                                self.fileLogger.log("Successfully renamed \(file) to \(uniqueNewName)")
                                print("[DEBUG] Successfully renamed \(file) to \(uniqueNewName)")
                                self.knownFiles.insert(uniqueNewName)
                                try? fileManager.removeItem(atPath: backupPath) // Remove backup after successful rename
                            } catch {
                                self.logger.error("[DEBUG] Failed to rename \(file) to \(uniqueNewName): \(error.localizedDescription)")
                                self.fileLogger.log("ERROR: Failed to rename \(file) to \(uniqueNewName): \(error.localizedDescription)")
                                print("[DEBUG] Failed to rename \(file) to \(uniqueNewName): \(error.localizedDescription)")
                                
                                // Restore from backup if rename failed
                                if fileManager.fileExists(atPath: backupPath) {
                                    self.fileLogger.log("Restoring from backup...")
                                    try? fileManager.removeItem(atPath: filePath) // Remove potentially corrupted file
                                    try? fileManager.moveItem(atPath: backupPath, toPath: filePath) // Restore original
                                    self.fileLogger.log("Restored file from backup")
                                }
                                self.knownFiles.insert(file)
                            }
                        } else {
                            // Rename the file with the suggested name
                            do {
                                try fileManager.moveItem(atPath: filePath, toPath: newFilePath)
                                self.logger.info("[DEBUG] Successfully renamed \(file) to \(newName)")
                                self.fileLogger.log("Successfully renamed \(file) to \(newName)")
                                print("[DEBUG] Successfully renamed \(file) to \(newName)")
                                self.knownFiles.insert(newName)
                                try? fileManager.removeItem(atPath: backupPath) // Remove backup after successful rename
                            } catch {
                                self.logger.error("[DEBUG] Failed to rename \(file) to \(newName): \(error.localizedDescription)")
                                self.fileLogger.log("ERROR: Failed to rename \(file) to \(newName): \(error.localizedDescription)")
                                print("[DEBUG] Failed to rename \(file) to \(newName): \(error.localizedDescription)")
                                
                                // Restore from backup if rename failed
                                if fileManager.fileExists(atPath: backupPath) {
                                    self.fileLogger.log("Restoring from backup...")
                                    try? fileManager.removeItem(atPath: filePath) // Remove potentially corrupted file
                                    try? fileManager.moveItem(atPath: backupPath, toPath: filePath) // Restore original
                                    self.fileLogger.log("Restored file from backup")
                                }
                                self.knownFiles.insert(file)
                            }
                        }
                    } catch {
                        self.logger.error("[DEBUG] Error processing file \(file): \(error.localizedDescription)")
                        self.fileLogger.log("ERROR: Error processing file \(file): \(error.localizedDescription)")
                        print("[DEBUG] Error processing file \(file): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("[DEBUG] Error reading directory: \(error.localizedDescription)")
            fileLogger.log("ERROR: Error reading directory: \(error.localizedDescription)")
            print("[DEBUG] Error reading directory: \(error.localizedDescription)")
        }
    }
    
    // Function to extract text content from PDF files
    private func extractPDFContent(filePath: String) -> String {
        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath)) else {
            fileLogger.log("Failed to create PDF document from file: \(filePath)")
            return ""
        }
        
        var pdfContent = ""
        
        // Process only up to 5 pages to avoid too much content
        let pageCount = min(pdfDocument.pageCount, 5)
        for i in 0..<pageCount {
            if let page = pdfDocument.page(at: i), let pageContent = page.string {
                pdfContent += pageContent + "\n"
                
                // If we already have a good amount of text, stop
                if pdfContent.count > 1000 {
                    break
                }
            }
        }
        
        return pdfContent
    }
    
    // Helper function to validate filenames
    private func isValidFilename(_ filename: String) -> Bool {
        // Check if filename contains invalid characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        if filename.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }
        
        // Check if filename is too long (some filesystems have limits)
        if filename.count > 255 {
            return false
        }
        
        return true
    }
    
    // Helper function to sanitize filenames
    private func sanitizeFilename(_ filename: String, originalExtension: String) -> String {
        // Remove invalid characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var sanitizedFilename = filename.components(separatedBy: invalidCharacters).joined()
        
        // Ensure the extension is preserved
        if !originalExtension.isEmpty && !(sanitizedFilename as NSString).pathExtension.lowercased().contains(originalExtension.lowercased()) {
            sanitizedFilename = (sanitizedFilename as NSString).deletingPathExtension + "." + originalExtension
        }
        
        return sanitizedFilename
    }
}

// File Logger implementation
class FileLogger {
    private let fileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.maxprudhomme.filelogger")
    
    init(directory: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        self.fileURL = directory.appendingPathComponent("sorta_log_\(dateString).txt")
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Log file location to make it easier to find
        let message = "--- Log file initialized at \(self.fileURL.path) ---"
        try? message.write(to: self.fileURL, atomically: true, encoding: .utf8)
    }
    
    func log(_ message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let timestamp = self.dateFormatter.string(from: Date())
            let logMessage = "[\(timestamp)] \(message)\n"
            
            if let fileHandle = try? FileHandle(forWritingTo: self.fileURL) {
                fileHandle.seekToEndOfFile()
                if let data = logMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // If the file doesn't exist yet, create it
                try? logMessage.write(to: self.fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
