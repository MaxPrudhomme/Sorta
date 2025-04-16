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
    @StateObject private var daemonManager = HelperManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(daemonManager)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}

class AppSettings: ObservableObject {
    private let sharedDefaults: UserDefaults

    init() {
        self.sharedDefaults = UserDefaults(suiteName: "group.com.maxprudhomme.sorta") ?? UserDefaults.standard
    }
}

