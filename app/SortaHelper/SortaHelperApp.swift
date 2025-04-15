//
//  SortaHelperApp.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import SwiftUI
import Combine
import LLM
import PDFKit

@main
struct SortaHelperApp: App {
    @StateObject private var daemon = SortaDaemon()
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Sorta Helper is running in the background")
                    .font(.title2)
                    .padding()
                
                Text("This helper app monitors your specified folder and automatically suggests better filenames for new files.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Open Logs Folder") {
                    openLogsFolder()
                }
                .padding()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding()
            }
            .frame(width: 400, height: 300)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
    
    private func openLogsFolder() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.maxprudhomme.SortaHelper"
        let logsDirectory = appSupportURL.appendingPathComponent(bundleID).appendingPathComponent("Logs")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
        
        // Open the directory in Finder
        NSWorkspace.shared.open(logsDirectory)
    }
}


