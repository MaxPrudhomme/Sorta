//
//  ContentView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 14/04/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedView: SelectedView = .dashboard
    @State private var recentFiles: [String] = []

    let client = DaemonClient()
    let manager = DaemonManager()
    
    var body: some View {
        // Call connect if the daemon is running
        Task { @MainActor in
            if await manager.isRunning {
                client.connect()
            }
        }
        
        return NavigationSplitView {
            List(selection: $selectedView) {
                Section(header: Text("Workspace")) {
                    NavigationLink(value: SelectedView.dashboard) {
                        Label("Dashboard", systemImage: "rectangle.3.group")
                    }
                    NavigationLink(value: SelectedView.chat) {
                        Label("Chat", systemImage: "brain")
                    }
                    NavigationLink(value: SelectedView.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }

                Section(header: Text("Recent Files")) {
                    if recentFiles.isEmpty {
                        Text("No recent items")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recentFiles, id: \.self) { file in
                            NavigationLink(value: SelectedView.file(URL(string: file)!)) {
                                Text(file)
                            }
                        }
                    }
                }
            }
        } detail: {
            switch selectedView {
            case .settings:
                SettingsView(vm: SettingsViewModel(manager: manager))
                    .navigationTitle("Settings")
            case .dashboard:
                Text("Dashboard View")
                    .navigationTitle("Dashboard")
            case .chat:
                ChatView(vm: ChatViewModel(client: client))
                    .navigationTitle("Chat")
            case .file(let fileURL):
                Text("You selected file: \(fileURL.lastPathComponent)")
                    .font(.headline)
                    .padding()
                    .navigationTitle(fileURL.lastPathComponent)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    enum SelectedView: Hashable {
        case dashboard
        case settings
        case chat
        case file(URL)
    }
}
