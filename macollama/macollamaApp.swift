//
//  macollamaApp.swift
//  macollama
//
//  Created by BillyPark on 1/29/25.
//

import SwiftUI

@main
struct macollamaApp: App {
    init() {
        // Migrate API keys from UserDefaults to Keychain
        SecureConfigurationManager.shared.migrateFromUserDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("")
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
