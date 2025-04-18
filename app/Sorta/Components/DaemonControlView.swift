//
//  DaemonControlView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 18/04/2025.
//

import SwiftUI

struct DaemonControlView: View {
    @State private var isRunning = false
    @State private var isBusy = false
    @State private var lastError: Error?
    
    let manager: DaemonManager
    let client: DaemonClient

    var body: some View {
        HStack {
            Text(client.connectionState.label)
                .foregroundColor(client.connectionState.color)
            
            Button(action: { Task { await toggleDaemon() } }) {
                Image(systemName: isRunning ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isRunning ? .blue : .gray)
            }
            .disabled(isBusy)
        }
        .onAppear {
            Task { await refresh() }
        }
    }
    
    private func refresh() async {
        isRunning = await manager.checkDaemonStatus()
    }

    private func toggleDaemon() async {
        isBusy = true
        lastError = nil
        do {
            if await manager.checkDaemonStatus() {
                client.disconnect()
                try await manager.stopAndUninstall()
            } else {
                try await manager.installAndStart()
                if await manager.checkDaemonStatus() {
                    Task { @MainActor in
                        client.connect()
                    }
                }
            }
            isRunning = await manager.checkDaemonStatus()
        } catch {
            lastError = error
        }
        isBusy = false
    }
}

extension DaemonClient.ConnectionState: Equatable {
    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .blue
        case .error: return .red
        }
    }
    
    static func == (lhs: DaemonClient.ConnectionState, rhs: DaemonClient.ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.error, .error):
            return true
        default:
            return false
        }
    }
}
