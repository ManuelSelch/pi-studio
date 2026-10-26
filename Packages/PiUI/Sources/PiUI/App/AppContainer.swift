import FactoryKit
import Flux
import Router
import SwiftUI

enum AppRoute: Hashable {
    case settings
}

/// One modal presentation scope for the app content. The router alone owns whether settings is
/// presented; `SettingsMiddleware` drives it, and the app only translates native dismissal back
/// to editing cleanup.
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
        .onChange(of: modal.presentation?.id) { _, newValue in
            guard newValue == nil else { return }
            Self.settingsFlowEnded(in: settings)
        }
    }

    /// A native dismissal only signals editing cleanup; it never re-creates visibility sync.
    /// Saving already blocks dismissal through the router guard, so this stays a defensive check.
    static func settingsFlowEnded(in store: FluxStore<SettingsFeature>) {
        guard !store.state.isSaving else { return }
        store.dispatch(.cancelled)
    }
}
