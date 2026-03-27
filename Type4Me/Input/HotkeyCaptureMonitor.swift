import Cocoa

struct HotkeyCaptureEvent {
    enum Kind {
        case flagsChanged
        case keyDown
    }

    let kind: Kind
    let keyCode: Int
    let modifiers: UInt64
    let isRepeat: Bool
}

final class HotkeyCaptureMonitor: NSObject {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var handler: (@MainActor (HotkeyCaptureEvent) -> Void)?

    @discardableResult
    func start(handler: @escaping @MainActor (HotkeyCaptureEvent) -> Void) -> Bool {
        stop()
        self.handler = handler

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCaptureCallback,
            userInfo: userInfo
        ) else {
            // Fallback for hotkey recording inside our own settings window. This keeps
            // normal keys bindable even when Accessibility/TCC is unavailable.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                guard let self else { return event }

                let kind: HotkeyCaptureEvent.Kind
                switch event.type {
                case .flagsChanged:
                    kind = .flagsChanged
                case .keyDown:
                    kind = .keyDown
                default:
                    return event
                }

                let captureEvent = HotkeyCaptureEvent(
                    kind: kind,
                    keyCode: Int(event.keyCode),
                    modifiers: UInt64(event.modifierFlags.rawValue),
                    isRepeat: event.isARepeat
                )

                Task { @MainActor in
                    self.handler?(captureEvent)
                }
                return nil
            }
            return localMonitor != nil
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        handler = nil
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let kind: HotkeyCaptureEvent.Kind
        switch type {
        case .flagsChanged:
            kind = .flagsChanged
        case .keyDown:
            kind = .keyDown
        default:
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = effectiveModifierFlags(for: event)
        let isRepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if let handler {
            let captureEvent = HotkeyCaptureEvent(
                kind: kind,
                keyCode: keyCode,
                modifiers: UInt64(modifiers.rawValue),
                isRepeat: isRepeat
            )
            Task { @MainActor in
                handler(captureEvent)
            }
        }

        // Swallow events while the capture UI is active so they do not trigger UI actions.
        return nil
    }

    private func normalizedModifierFlags(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn])
    }

    private func effectiveModifierFlags(for event: CGEvent) -> CGEventFlags {
        let eventFlags = normalizedModifierFlags(event.flags)
        let sourceFlags = normalizedModifierFlags(CGEventSource.flagsState(.combinedSessionState))
        return eventFlags.union(sourceFlags)
    }
}

private func hotkeyCaptureCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyCaptureMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handleEvent(type: type, event: event)
}
