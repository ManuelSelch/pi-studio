import SwiftUI
import Flux
import FactoryKit

struct SettingsContainer: View {
    @InjectedObject(\.settingsStore) var store

    var body: some View {
        SettingsScreen(
            endpoint: store.state.draft,
            error: store.state.error,
            isSaving: store.state.isSaving,
                       
            onEndpointChanged: { store.dispatch(.draftChanged($0)) },
            onSave: { store.dispatch(.saveTapped) },
            onCancel: { store.dispatch(.cancelTapped) }
        )
        #if os(iOS)
        .presentationDetents([.height(300)])
        #endif
    }
}
