import Foundation
import os

// Shared model for file organization between main app and helper
struct FileOrganizer {
    private let logger = Logger(subsystem: "com.maxprudhomme.Sorta", category: "FileOrganizer")
    
    // Categorizes files by their extension type
    enum FileCategory: String, CaseIterable {
        case images = "Images"
        case documents = "Documents"
        case videos = "Videos"
        case audio = "Audio"
        case archives = "Archives"
        case code = "Code"
        case other = "Other"
        
        // Map file extensions to categories
        static func category(for fileExtension: String) -> FileCategory {
            let ext = fileExtension.lowercased()
            
            switch ext {
            case "jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic", "webp":
                return .images
                
            case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key":
                return .documents
                
            case "mp4", "mov", "avi", "wmv", "mkv", "flv", "webm":
                return .videos
                
            case "mp3", "wav", "aac", "flac", "ogg", "m4a":
                return .audio
                
            case "zip", "rar", "7z", "tar", "gz", "dmg", "iso":
                return .archives
                
            case "swift", "js", "py", "java", "c", "cpp", "h", "html", "css", "php", "rb", "go", "rust", "ts", "json", "xml":
                return .code
                
            default:
                return .other
            }
        }
    }
    
    // Organizes files in a directory based on their type
    func organizeFiles(in directoryPath: String) {
        let fileManager = FileManager.default
        
        do {
            // Get all files in the directory
            let files = try fileManager.contentsOfDirectory(atPath: directoryPath)
            
            // Skip hidden files and create category folders if needed
            for file in files where !file.hasPrefix(".") {
                let filePath = (directoryPath as NSString).appendingPathComponent(file)
                
                // Get the file extension
                let fileExtension = (file as NSString).pathExtension
                
                // Skip directories
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
                    continue
                }
                
                // Get the appropriate category for this file
                let category = FileCategory.category(for: fileExtension)
                
                // Create the category folder if it doesn't exist
                let categoryFolderPath = (directoryPath as NSString).appendingPathComponent(category.rawValue)
                if !fileManager.fileExists(atPath: categoryFolderPath) {
                    try fileManager.createDirectory(atPath: categoryFolderPath, withIntermediateDirectories: true)
                }
                
                // Move the file to its category folder
                let destinationPath = (categoryFolderPath as NSString).appendingPathComponent(file)
                
                // Only move if destination doesn't already exist
                if !fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.moveItem(atPath: filePath, toPath: destinationPath)
                    logger.info("Moved file \(file) to \(category.rawValue) folder")
                } else {
                    logger.warning("Destination file already exists: \(destinationPath)")
                }
            }
        } catch {
            logger.error("Error organizing files: \(error.localizedDescription)")
        }
    }
}