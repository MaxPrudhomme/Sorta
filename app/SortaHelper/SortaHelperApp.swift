//
//  SortaHelperApp.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//

import SwiftUI

@main
struct SortaHelperApp: App {
    @StateObject private var daemon = SortaDaemon()
    
    var body: some Scene {
        Settings {
            EmptyView().hidden()
        }
    }
}
