import SwiftUI
import Flux
import FactoryKit

struct SettingsContainer: View {
    @Injected(\.settingsStore) var store

    var body: some View {
        SettingsScreen(
            endpoint: store.state.draft,
            error: store.state.error,
            isSaving: store.state.isSaving,
                       
            onEndpointChanged: { store.dispatch(.draftChanged($0)) },
            onSave: { store.dispatch(.saveTapped) },
            onCancel: { store.dispatch(.cancelled) }
        )
        .interactiveDismissDisabled(store.state.isSaving)
        #if os(iOS)
        .presentationDetents([.height(300)])
        #endif
    }
}
