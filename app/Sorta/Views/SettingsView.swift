//
//  SettingsView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        VStack(spacing: 20) {
            Button(action: { Task { await vm.toggleDaemon() } }) {
                Text(vm.isRunning ? "Stop Daemon" : "Start Daemon")
            }
            .disabled(vm.isBusy)

            if let error = vm.lastError {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onAppear { Task { await vm.refresh() } }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    private let manager: DaemonManager
    
    @Published private(set) var isRunning = false
    @Published private(set) var isBusy = false
    @Published var lastError: Error?
    
    init(manager: DaemonManager) {
        self.manager = manager
    }

    func refresh() async {
        isRunning = await manager.isRunning()
    }

    func toggleDaemon() async {
        isBusy = true
        lastError = nil
        do {
            if await manager.isRunning() {
                try await manager.stopAndUninstall()
            } else {
                try await manager.installAndStart()
            }
            isRunning = await manager.isRunning()
        } catch {
            lastError = error
        }
        isBusy = false
    }
}
