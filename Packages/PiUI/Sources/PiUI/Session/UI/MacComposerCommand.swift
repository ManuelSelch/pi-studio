/// Presentation-only command policy, independent of AppKit events and session effects.
enum MacComposerKey { case returnKey, escape }

struct MacComposerModifiers: OptionSet, Sendable {
    let rawValue: Int
    static let shift = Self(rawValue: 1 << 0)
    static let command = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)
}

enum MacComposerCommand: Equatable {
    case native, consume, submit, stop

    static func resolve(key: MacComposerKey, modifiers: MacComposerModifiers,
                        isComposing: Bool, isRepeat: Bool,
                        canEdit: Bool, canSend: Bool, canStop: Bool) -> Self {
        guard !isComposing else { return .native }
        switch key {
        case .returnKey:
            guard modifiers.subtracting(.shift).isEmpty else { return .native }
            if modifiers.contains(.shift) { return canEdit ? .native : .consume }
            return !isRepeat && canSend ? .submit : .consume
        case .escape:
            guard modifiers.isEmpty, canStop else { return .native }
            return isRepeat ? .consume : .stop
        }
    }
}
