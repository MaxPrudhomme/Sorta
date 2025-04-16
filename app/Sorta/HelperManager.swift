//
//  HelperManager.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 16/04/2025.
//


import Foundation
import ServiceManagement
import AppKit
import Combine

class HelperManager: ObservableObject {
    static let helperBundleID = "com.maxprudhomme.SortaHelper"
    static let appGroup = "group.com.maxprudhomme.sorta"
    
    @Published var isHelperRunning: Bool = false
    @Published var startAtLogin: Bool {
        didSet {
            setStartAtLogin(startAtLogin)
        }
    }
    
    private var runningAppsCancellable: AnyCancellable?
    
    init() {
        let defaults = UserDefaults(suiteName: Self.appGroup)
        self.startAtLogin = defaults?.bool(forKey: "startAtLogin") ?? false
        
        // Poll every 2 seconds to keep status up-to-date
        runningAppsCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateHelperStatus()
            }
        // Initial status
        updateHelperStatus()
    }
    
    func updateHelperStatus() {
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Self.helperBundleID
        }
        if isHelperRunning != isRunning {
            isHelperRunning = isRunning
        }
    }
    
    func startHelper() {
        guard !isHelperRunning else { return }
        guard let helperURL = Self.findHelperURL() else {
            print("Could not find helper app")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: helperURL, configuration: config) { [weak self] app, error in
            if let error = error {
                print("Failed to launch helper: \(error.localizedDescription)")
            } else {
                // Give the system a moment to launch the helper
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.updateHelperStatus()
                }
            }
        }
    }
    
    func stopHelper() {
        DistributedNotificationCenter.default().post(
            name: Notification.Name("\(Self.helperBundleID).shutdown"),
            object: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.updateHelperStatus()
        }
    }
    
    func setStartAtLogin(_ enabled: Bool) {
        do {
            let loginItem = SMAppService.loginItem(identifier: Self.helperBundleID)
            if enabled {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
            UserDefaults(suiteName: Self.appGroup)?.set(enabled, forKey: "startAtLogin")
        } catch {
            print("Failed to update login item: \(error.localizedDescription)")
        }
    }
    
    static func findHelperURL() -> URL? {
        let mainBundle = Bundle.main
        let loginItemsURL = mainBundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("SortaHelper.app")
        return FileManager.default.fileExists(atPath: loginItemsURL.path) ? loginItemsURL : nil
    }
    
    
}
