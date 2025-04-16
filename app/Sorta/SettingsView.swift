//
//  ContentView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var helperManager: HelperManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sorta")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            statusView
            
            settingsView
            
            Spacer()
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 400)
    }

    private var statusView: some View {
        HStack {
            Circle()
                .fill(helperManager.isHelperRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(helperManager.isHelperRunning ? "Helper is active" : "Helper is not running")
                .foregroundStyle(helperManager.isHelperRunning ? .primary : .secondary)
            
            Spacer()
            
            if helperManager.isHelperRunning {
                Button("Stop Helper") {
                    helperManager.stopHelper()
                }
            } else {
                Button("Start Helper") {
                    helperManager.startHelper()
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
            
            Toggle("Start helper at login", isOn: $helperManager.startAtLogin)
                .padding(.leading, 4)

        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
}
