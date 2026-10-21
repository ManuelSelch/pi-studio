import Testing
@testable import PiUI

struct MacComposerCommandTests {
    @Test func returnSharesReadinessGuardAndIgnoresRepeats() {
        #expect(command(.returnKey) == .submit)
        #expect(command(.returnKey, canSend: false) == .consume)
        #expect(command(.returnKey, isRepeat: true) == .consume)
        #expect(command(.returnKey, canEdit: false, canSend: false) == .consume)
    }

    @Test func shiftReturnUsesNativeInsertionOnlyWhenEditable() {
        #expect(command(.returnKey, modifiers: .shift) == .native)
        #expect(command(.returnKey, modifiers: .shift, canEdit: false) == .consume)
        #expect(command(.returnKey, modifiers: .shift, canSend: false) == .native)
    }

    @Test func unrelatedModifiersAndInputMethodStayNative() {
        for modifiers: MacComposerModifiers in [.command, .option, .control, [.shift, .command]] {
            #expect(command(.returnKey, modifiers: modifiers) == .native)
            #expect(command(.escape, modifiers: modifiers, canStop: true) == .native)
        }
        #expect(command(.returnKey, isComposing: true) == .native)
        #expect(command(.escape, isComposing: true, canStop: true) == .native)
    }

    @Test func escapeStopsOnlyEligibleRunOnce() {
        #expect(command(.escape, canStop: true) == .stop)
        #expect(command(.escape) == .native)
        #expect(command(.escape, isRepeat: true, canStop: true) == .consume)
        #expect(command(.escape, modifiers: .shift, canStop: true) == .native)
    }

    private func command(_ key: MacComposerKey, modifiers: MacComposerModifiers = [],
                         isComposing: Bool = false, isRepeat: Bool = false,
                         canEdit: Bool = true, canSend: Bool = true,
                         canStop: Bool = false) -> MacComposerCommand {
        MacComposerCommand.resolve(key: key, modifiers: modifiers, isComposing: isComposing,
                                   isRepeat: isRepeat, canEdit: canEdit, canSend: canSend, canStop: canStop)
    }
}
