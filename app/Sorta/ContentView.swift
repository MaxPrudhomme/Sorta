//
//  ContentView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 14/04/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ViewModel()

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

extension ContentView {
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var isRunning = false
        @Published private(set) var isBusy = false
        @Published var lastError: Error?

        let manager = DaemonManager()

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
}
