//
//  AppDelegate.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 18/04/2025.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    let client: DaemonClient = DaemonClient()
    let manager: DaemonManager = DaemonManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Task {
            if await manager.checkDaemonStatus() {
                client.connect()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        client.disconnect()
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        if case .disconnected = client.connectionState {
            Task {
                if await manager.checkDaemonStatus() {
                    client.connect()
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
