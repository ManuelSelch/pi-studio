//
//  pi_studioApp.swift
//  pi-studio
//
//  Created by Manuel Selch on 20.10.26.
//

import SwiftUI

@main
struct pi_studioApp: App {
    @State private var demoSession: DemoSessionModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            _demoSession = State(initialValue: DemoSessionModel(makeConnection: { _ in
                UITestConnection(rejectSend: rejected, unknownSend: unknown)
            }))
            return
        }
        #endif
        _demoSession = State(initialValue: DemoSessionModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(demoSession)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await demoSession.disconnect() } }
                }
        }
    }
}
