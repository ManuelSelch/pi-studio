//
//  pi_studioApp.swift
//  pi-studio
//
//  Created by Manuel Selch on 20.10.26.
//

import SwiftUI

@main
struct pi_studioApp: App {
    @State private var demoSession = DemoSessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(demoSession)
        }
    }
}
