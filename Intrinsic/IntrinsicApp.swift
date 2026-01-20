//
//  IntrinsicApp.swift
//  Intrinsic
//
//  Created by Arthur Louette on 03/01/2026.
//

import SwiftUI

@main
struct IntrinsicApp: App {
    // On lit le thème stocké pour l'appliquer globalement
    @AppStorage("appTheme") private var appTheme: String = "System"

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Appliquer le thème choisi
                .preferredColorScheme(
                    appTheme == "Light" ? .light :
                    appTheme == "Dark" ? .dark : nil
                )
        }
        
        // --- C'est ici qu'on active le menu Préférences ---
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
