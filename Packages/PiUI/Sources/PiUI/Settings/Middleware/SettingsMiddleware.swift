import FactoryKit
import Flux
import Foundation
import Router

/// Owns settings presentation: it presents, dismisses and guards the one app-scoped modal flow.
/// The feature keeps only editing/persistence state, so there is no visibility flag to synchronize.
@MainActor
final class SettingsMiddleware: Middleware {
    typealias F = SettingsFeature

    @Injected(\.endpointSettingsService) private var service
    private let modal: ModalRouter<AppRoute>
    private var store: StoreHandle<SettingsFeature>?
    private var presentedFlowId: UUID?
    private var saveInFlight = false

    init(modal: ModalRouter<AppRoute>) {
        self.modal = modal
    }

    func initialize(_ store: StoreHandle<SettingsFeature>) { self.store = store }

    func handle(_ state: SettingsFeature.State, _ action: SettingsFeature.Action) async -> SettingsFeature.Action? {
        switch action {
        case .opened:
            return presentIfNeeded()
        case .cancelTapped:
            saveInFlight = false
            syncCanDismiss(false)
            dismissPresentedFlow()
            return nil
        case .saveTapped:
            return save(state)
        case .saved:
            saveInFlight = false
            syncCanDismiss(false)
            dismissPresentedFlow()
            return nil
        case .saveFailed:
            saveInFlight = false
            syncCanDismiss(false)
            return nil
        case .flowStarted, .saveAbandoned, .draftChanged:
            return nil
        }
    }

    /// A duplicate open preserves the active flow, so only a scope without a settings flow resets.
    private func presentIfNeeded() -> SettingsFeature.Action? {
        guard !isSettingsPresented else { return nil }
        guard modal.present(.settings) else { return nil }
        presentedFlowId = modal.presentation?.id
        saveInFlight = false
        syncCanDismiss(false)
        return .flowStarted
    }

    private func save(_ state: SettingsFeature.State) -> SettingsFeature.Action? {
        // Saving needs a presented flow; without one nothing is persisted and saving is released.
        guard isSettingsPresented else { return .saveAbandoned }
        // The reducer already marked the accepted Save; the token rejects any duplicate.
        guard state.isSaving, !saveInFlight else { return nil }
        saveInFlight = true
        syncCanDismiss(true)
        guard let endpoint = ServerEndpoint.validated(state.draft) else {
            return .saveFailed(ServerEndpoint.validationMessage)
        }
        do {
            try service.save(endpoint)
            return .saved(endpoint)
        } catch {
            return .saveFailed(error.localizedDescription)
        }
    }

    private var isSettingsPresented: Bool {
        modal.presentation?.stack.root == .settings
    }

    /// Only the flow the middleware presented may dismiss; a newer flow is left untouched.
    private func dismissPresentedFlow() {
        guard let id = presentedFlowId else { return }
        if modal.presentation?.id == id {
            _ = modal.dismiss(id: id)
        }
        presentedFlowId = nil
    }

    private func syncCanDismiss(_ isSaving: Bool) {
        guard isSettingsPresented else { return }
        modal.presentation?.canDismiss = !isSaving
    }
}
