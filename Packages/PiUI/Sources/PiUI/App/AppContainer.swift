import FactoryKit
import Flux
import Router
import SwiftUI

enum AppRoute: Hashable {
    case settings
}

/// One modal presentation scope for the app content. The router alone owns whether settings is
/// presented; `SettingsMiddleware` drives it. Editing state resets when a new flow starts.
public struct AppContainer: View {
    @InjectedObject(\.settingsStore) private var settings
    @Injected(\.settingsModal) private var modal

    public init() {}

    public var body: some View {
        ModalRouterView(modal) {
            WorkspaceContainer(
                onOpenSettings: { settings.dispatch(.opened) },
                isSettingsPresented: modal.presentation != nil
            )
        } destination: { flow in
            switch flow.stack.root {
            case .settings:
                SettingsContainer()
            }
        }
    }
}
