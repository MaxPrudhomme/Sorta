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
    private var directoryMonitor: DirectoryMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        logger.info("SortaHelper daemon started")
        setupMonitoring()
        setupShutdownListener()
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
        

        directoryMonitor = DirectoryMonitor(path: path)
        directoryMonitor?.startMonitoring()
    }
}
