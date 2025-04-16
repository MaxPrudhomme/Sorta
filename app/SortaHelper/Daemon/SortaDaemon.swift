//
//  SortaDaemon.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import SwiftUI
import Combine


final class SortaDaemon: ObservableObject {
    private let logger = Logger(subsystem: "com.maxprudhomme.SortaBettaHelper", category: "Daemon")
    
    init() {
        logger.info("SortaBettaHelper daemon started")
        setupShutdownListener()
    }
    
    private func setupShutdownListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.maxprudhomme.SortaHelper.shutdown"),
            object: nil,
            queue: .main
        ) { _ in
            exit(0)
        }
    }
}
