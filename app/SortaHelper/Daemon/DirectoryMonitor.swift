//
//  DirectoryMonitor.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import Combine

class DirectoryMonitor {
    private var fileDescriptor: CInt = -1
    private let queue = DispatchQueue(label: "com.maxprudhomme.directorymonitor", attributes: .concurrent)
    private var source: DispatchSourceFileSystemObject?
    private let logger = Logger(subsystem: "com.maxprudhomme.SortaHelper", category: "DirectoryMonitor")
    private let fileOrganizer = FileOrganizer()
    
    private var processingTimer: Timer?
    private let processingInterval: TimeInterval = 2.0
    
    let path: String
    
    init(path: String) {
        self.path = path
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
            logger.error("Failed to open directory at path: \(self.path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .attrib, .extend, .link, .delete, .revoke],
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.logger.info("Detected changes in monitored directory: \(self.path)")
            
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
            self.logger.info("Directory monitoring stopped")
        }
        
        source?.resume()
        logger.info("Directory monitoring started for: \(self.path)")
        
        processFiles()
    }
    
    func stopMonitoring() {
        processingTimer?.invalidate()
        processingTimer = nil
        source?.cancel()
        source = nil
    }
    
    private func processFiles() {
        logger.info("Processing files in: \(self.path)")
        
        fileOrganizer.organizeFiles(in: path)
    }
}
