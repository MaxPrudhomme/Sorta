//
//  SortaApp.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 14/04/2025.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct SortaApp: App {
    @StateObject private var appSettings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
    
    private func registerLoginItem() {
        do {
            try SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").register()
        } catch {
            print("Failed to register login item: \(error.localizedDescription)")
        }
    }
    
    private func unregisterLoginItem() {
        do {
            try SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").unregister()
        } catch {
            print("Failed to unregister login item: \(error.localizedDescription)")
        }
    }
}

class AppSettings: ObservableObject {
    private let sharedDefaults: UserDefaults
    
    @Published var monitoredFolderPath: String {
        didSet {
            sharedDefaults.set(monitoredFolderPath, forKey: "monitoredFolderPath")
        }
    }
    
    @Published var startAtLogin: Bool {
        didSet {
            if startAtLogin {
                do {
                    try SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").register()
                } catch {
                    print("Failed to register login item: \(error.localizedDescription)")
                }
            } else {
                do {
                    try SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").unregister()
                } catch {
                    print("Failed to unregister login item: \(error.localizedDescription)")
                }
            }
            
            UserDefaults.standard.set(startAtLogin, forKey: "startAtLogin")
        }
    }
    
    init() {
        self.sharedDefaults = UserDefaults(suiteName: "group.com.maxprudhomme.sorta") ?? UserDefaults.standard
        
        self.monitoredFolderPath = self.sharedDefaults.string(forKey: "monitoredFolderPath") ?? ""
        self.startAtLogin = UserDefaults.standard.bool(forKey: "startAtLogin")
    }
}
