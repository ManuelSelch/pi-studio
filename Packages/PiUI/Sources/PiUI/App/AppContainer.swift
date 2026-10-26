import FactoryKit
import Flux
import Router
import SwiftUI

enum AppRoute: Hashable {
    case settings
}

/// One modal presentation scope for the app content. Settings business state remains in Flux;
/// Router owns native presentation identity and translates user dismissal back to Cancel.
public struct AppContainer: View {
    @InjectedObject(\.settingsStore) private var settings
    @State private var modal = ModalRouter<AppRoute>()

    public init() {}

    public var body: some View {
        ModalRouterView(modal) {
            WorkspaceContainer(onOpenSettings: { Self.openSettings(in: settings) })
        } destination: { flow in
            switch flow.stack.root {
            case .settings:
                SettingsContainer()
            }
        }
        .onChange(of: settings.state, initial: true) { _, state in
            Self.synchronizeSettings(state, modal: modal)
        }
        .onChange(of: modal.presentation?.id) { _, _ in
            Self.settingsDismissed(in: settings, modal: modal)
        }
    }

    static func openSettings(in store: FluxStore<SettingsFeature>) {
        guard !store.state.isPresented else { return }
        store.dispatch(.opened)
    }

    static func synchronizeSettings(_ state: SettingsFeature.State, modal: ModalRouter<AppRoute>) {
        if state.isPresented {
            if modal.presentation == nil { modal.present(.settings) }
            modal.presentation?.canDismiss = !state.isSaving
        } else if let flow = modal.presentation {
            // Save completion must release the guard before dismissing its original flow.
            flow.canDismiss = true
            modal.dismiss(id: flow.id)
        }
    }

    static func settingsDismissed(in store: FluxStore<SettingsFeature>, modal: ModalRouter<AppRoute>) {
        guard modal.presentation == nil, store.state.isPresented else { return }
        store.dispatch(.cancelled)
    }
}
