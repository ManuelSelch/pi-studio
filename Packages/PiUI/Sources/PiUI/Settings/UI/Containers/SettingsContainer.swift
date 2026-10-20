import SwiftUI
import Flux

struct SettingsContainer: View {
    let controller: SettingsController
    @ObservedObject private var store: FluxStore<SettingsFeature>

    init(controller: SettingsController) {
        self.controller = controller
        _store = ObservedObject(wrappedValue: controller.store)
    }

    var body: some View {
        SettingsScreen(endpoint: store.state.draft, error: store.state.error,
                       isSaving: store.state.isSaving,
                       onEndpointChanged: controller.setDraft,
                       onSave: controller.save, onCancel: controller.cancel)
            .interactiveDismissDisabled(store.state.isSaving)
            #if os(iOS)
            .presentationDetents([.height(300)])
            #endif
    }
}
