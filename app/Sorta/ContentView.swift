//
//  ContentView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 14/04/2025.
//

import SwiftUI
import AppKit
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var isShowingFolderPicker = false
    @State private var isHelperRunning = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sorta")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Select a folder that you want to monitor and automatically organize")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            folderSelectionView
            
            statusView
            
            settingsView
            
            Spacer()
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            checkHelperStatus()
            startHelper()
            if appSettings.startAtLogin {
                try? SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").register()
            }
        }
    }
    
    private var folderSelectionView: some View {
        VStack(spacing: 10) {
            if appSettings.monitoredFolderPath.isEmpty {
                Text("No folder selected")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Monitoring folder:")
                    Text(appSettings.monitoredFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button("Select Folder") {
                    isShowingFolderPicker = true
                }
                
                if !appSettings.monitoredFolderPath.isEmpty {
                    Button("Use Documents Folder") {
                        useDocumentsFolder()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
        .sheet(isPresented: $isShowingFolderPicker) {
            FolderPickerView(selectedPath: $appSettings.monitoredFolderPath)
        }
    }
    
    private var statusView: some View {
        HStack {
            Circle()
                .fill(isHelperRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(isHelperRunning ? "Helper is active" : "Helper is not running")
                .foregroundStyle(isHelperRunning ? .primary : .secondary)
            
            Spacer()
            
            if isHelperRunning {
                Button("Stop Helper") {
                    stopHelper()
                }
            } else {
                Button("Start Helper") {
                    startHelper()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
    
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.headline)
            
            Toggle("Start helper at login", isOn: $appSettings.startAtLogin)
                .padding(.leading, 4)
                .onChange(of: appSettings.startAtLogin) {
                    do {
                        let helper = SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper")
                        if appSettings.startAtLogin {
                            try helper.register()
                            print("Helper registered for login")
                        } else {
                            try helper.unregister()
                            print("Helper unregistered from login")
                        }
                    } catch {
                        print("Failed to update login item: \(error)")
                    }
                }
            
            Divider()
            
            Text("Sorta organizes files by:")
                .font(.subheadline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                ForEach(FileOrganizer.FileCategory.allCases.prefix(3), id: \.self) { category in
                    GridRow {
                        Text(category.rawValue)
                            .bold()
                        
                        let exampleExtension = exampleExtension(for: category)
                        Text(exampleExtension)
                            .foregroundStyle(.secondary)
                    }
                }
                
                GridRow {
                    Text("And more...")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.center)
                        .gridCellColumns(2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
    
    private func exampleExtension(for category: FileOrganizer.FileCategory) -> String {
        switch category {
        case .images:
            return "jpg, png, gif..."
        case .documents:
            return "pdf, doc, txt..."
        case .videos:
            return "mp4, mov, avi..."
        case .audio:
            return "mp3, wav, aac..."
        case .archives:
            return "zip, rar, 7z..."
        case .code:
            return "swift, js, py..."
        case .other:
            return "other files"
        }
    }
    
    private func useDocumentsFolder() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            appSettings.monitoredFolderPath = documentsURL.path
        }
    }
    
    private func checkHelperStatus() {
        // Check if the helper process is running
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.maxprudhomme.SortaHelper"
        }
        
        isHelperRunning = isRunning
    }
    
    private func startHelper() {
        // Try to launch the helper manually if it's not running
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "Contents/Library/LoginItems/SortaHelper.app") else {
            print("Could not find helper app")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false

        NSWorkspace.shared.openApplication(at: helperURL, configuration: config) { app, error in
            if let error = error {
                print("Failed to launch helper: \(error.localizedDescription)")
            } else {
                // Check status after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    checkHelperStatus()
                }
            }
        }
    }
    
    private func stopHelper() {
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.maxprudhomme.SortaHelper.shutdown"),
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkHelperStatus()
        }
    }
}

struct FolderPickerView: View {
    @Binding var selectedPath: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Select a folder to monitor")
                .font(.headline)
                .padding()
            
            Button("Choose Folder") {
                selectFolder()
            }
            .padding()
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 200)
    }
    
    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                selectedPath = url.path
                dismiss()
            } else {
                dismiss()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
