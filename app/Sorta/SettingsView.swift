//
//  ContentView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedFolderPath: String = ""
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
                if appSettings.startAtLogin {
                    try? SMAppService.loginItem(identifier: "com.maxprudhomme.SortaHelper").register()
                }
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
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
    
    private func useDocumentsFolder() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            appSettings.monitoredFolderPath = documentsURL.path
        }
    }
    
    private func checkHelperStatus() {
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.maxprudhomme.SortaHelper"
        }
        
        isHelperRunning = isRunning
    }
    
    private func startHelper() {
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
