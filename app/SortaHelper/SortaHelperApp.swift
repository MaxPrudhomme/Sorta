//
//  SortaHelperApp.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import Foundation
import os
import SwiftUI
import Combine

@main
struct SortaHelperApp: App {
    @StateObject private var sortaDaemon = SortaDaemon()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}


