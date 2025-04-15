//
//  SortaDaemon.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import SwiftUI
import Combine


final class SortaDaemon: ObservableObject {
    private let logger = Logger(subsystem: "com.maxprudhomme.SortaHelper", category: "FolderDaemon")
    private var cancellables = Set<AnyCancellable>()
    private var directoryMonitor: DirectoryMonitor?
    private var logsDirectory: URL?
    
    init() {
        logger.info("SortaHelper daemon started")
        createLogDirectory()
        setupMonitoring()
        setupShutdownListener()
    }
    
    private func createLogDirectory() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.maxprudhomme.SortaHelper"
        let logsDirectory = appSupportURL.appendingPathComponent(bundleID).appendingPathComponent("Logs")
        
        do {
            if !fileManager.fileExists(atPath: logsDirectory.path) {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            }
            self.logsDirectory = logsDirectory
            
            // Log the path to make it easy to find
            let logPath = logsDirectory.path
            logger.info("Logs directory created at: \(logPath)")
            print("LOGS DIRECTORY: \(logPath)")
            
            // Write the path to a more discoverable location - Desktop
            if let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
                let pathInfoFile = desktopURL.appendingPathComponent("sorta_logs_location.txt")
                try "Sorta logs are located at: \(logPath)".write(to: pathInfoFile, atomically: true, encoding: .utf8)
                logger.info("Created path info file at: \(pathInfoFile.path)")
            }
        } catch {
            logger.error("Failed to create logs directory: \(error.localizedDescription)")
            print("Failed to create logs directory: \(error.localizedDescription)")
        }
    }

    private func setupShutdownListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.maxprudhomme.SortaHelper.shutdown"),
            object: nil,
            queue: .main
        ) { _ in
            exit(0)
        }
    }
    
    private func setupMonitoring() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.maxprudhomme.sorta")
        
        let savedPath = sharedDefaults?.string(forKey: "monitoredFolderPath")
        let monitoredPath: String
        
        if let path = savedPath, !path.isEmpty {
            monitoredPath = path
            logger.info("Monitoring custom folder: \(path)")
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            monitoredPath = documentsURL.path
            logger.info("Monitoring default Documents folder: \(monitoredPath)")
        }
        
        startMonitoring(path: monitoredPath)
        
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.checkForPathChanges()
            }
            .store(in: &cancellables)
    }
    
    private func checkForPathChanges() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.maxprudhomme.sorta")
        if let newPath = sharedDefaults?.string(forKey: "monitoredFolderPath"),
           newPath != directoryMonitor?.path {
            logger.info("Path changed, updating monitor to: \(newPath)")
            startMonitoring(path: newPath)
        }
    }
    
    private func startMonitoring(path: String) {
        directoryMonitor?.stopMonitoring()
        
        // Check if path exists before starting monitor
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            logger.info("Starting monitoring on valid path: \(path)")
            directoryMonitor = DirectoryMonitor(path: path)
            directoryMonitor?.startMonitoring()
        } else {
            // Log error for non-existent path
            logger.error("Cannot monitor non-existent path: \(path)")
            print("ERROR: Cannot monitor non-existent path: \(path)")
            
            // Fall back to Documents folder
            if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
                logger.info("Falling back to Documents folder: \(documents)")
                print("Falling back to Documents folder: \(documents)")
                directoryMonitor = DirectoryMonitor(path: documents)
                directoryMonitor?.startMonitoring()
            }
        }
    }
}
