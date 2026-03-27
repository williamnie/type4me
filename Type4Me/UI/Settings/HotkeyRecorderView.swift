import SwiftUI
import Carbon.HIToolbox

struct HotkeyRecorderView: View {

    @Binding var keyCode: Int?
    @Binding var modifiers: UInt64?

    @State private var isRecording = false
    @State private var eventMonitor: HotkeyCaptureMonitor?
    @State private var pendingModifierCode: Int?
    @State private var pendingModifierModifiers: UInt64 = 0
    @State private var modifierCaptureTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            // Display current hotkey
            Text(displayText)
                .font(.system(size: 12))
                .foregroundStyle(isRecording ? TF.settingsAccentRed : TF.settingsTextSecondary)
                .frame(minWidth: 100, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(TF.settingsBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isRecording
                                ? TF.settingsAccentRed.opacity(0.5)
                                : TF.settingsTextTertiary.opacity(0.2),
                            lineWidth: 1
                        )
                )

            if isRecording {
                Button(L("取消", "Cancel")) { stopRecording() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TF.settingsTextSecondary)
            } else {
                Button(L("录制", "Record")) { startRecording() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TF.settingsTextSecondary)

                if keyCode != nil {
                    Button(L("清除", "Clear")) {
                        keyCode = nil
                        modifiers = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TF.settingsTextTertiary)
                }
            }
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Display

    private var displayText: String {
        if isRecording { return L("按下快捷键...", "Press a key...") }
        guard let kc = keyCode else { return L("未设置", "Not set") }
        return Self.keyDisplayName(keyCode: kc, modifiers: modifiers)
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        pendingModifierCode = nil
        modifierCaptureTask?.cancel()
        modifierCaptureTask = nil
        let monitor = HotkeyCaptureMonitor()
        guard monitor.start(handler: handleCaptureEvent) else {
            isRecording = false
            return
        }
        eventMonitor = monitor
    }

    @MainActor
    private func captureModifierOnlyKey(_ keyCode: Int, modifiers: UInt64 = 0) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        stopRecording()
    }

    private func stopRecording() {
        isRecording = false
        modifierCaptureTask?.cancel()
        modifierCaptureTask = nil
        pendingModifierCode = nil
        pendingModifierModifiers = 0
        eventMonitor?.stop()
        eventMonitor = nil
    }

    @MainActor
    private func handleCaptureEvent(_ event: HotkeyCaptureEvent) {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.modifiers))

        switch event.kind {
        case .flagsChanged:
            let kc = event.keyCode
            guard Self.modifierKeyCodes.contains(kc) else { return }
            let pressed = isModifierPressed(keyCode: kc, flags: flags)

            if pressed {
                pendingModifierCode = kc
                pendingModifierModifiers = modifierComboModifiers(for: kc, flags: flags)
                modifierCaptureTask?.cancel()
                modifierCaptureTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let pending = pendingModifierCode else { return }
                        captureModifierOnlyKey(pending, modifiers: pendingModifierModifiers)
                    }
                }
            } else if let pending = pendingModifierCode {
                modifierCaptureTask?.cancel()
                modifierCaptureTask = nil
                keyCode = pending
                modifiers = pendingModifierModifiers
                pendingModifierCode = nil
                pendingModifierModifiers = 0
                stopRecording()
            }

        case .keyDown:
            let kc = event.keyCode
            guard !event.isRepeat else { return }
            modifierCaptureTask?.cancel()
            modifierCaptureTask = nil
            pendingModifierCode = nil

            if kc == 53 && flags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad]).isEmpty {
                stopRecording()
                return
            }

            keyCode = kc
            let clean = flags.intersection([.command, .shift, .option, .control, .function])
            modifiers = clean.isEmpty ? 0 : UInt64(clean.rawValue)
            stopRecording()
        }
    }

    // MARK: - Modifier Press Detection

    static let modifierKeyCodes: Set<Int> = [54, 55, 56, 58, 59, 60, 61, 62, 63]

    private func isModifierPressed(keyCode: Int, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55: return flags.contains(.command)
        case 56, 60: return flags.contains(.shift)
        case 58, 61: return flags.contains(.option)
        case 59, 62: return flags.contains(.control)
        case 63: return flags.contains(.function)
        default: return false
        }
    }

    // MARK: - Modifier Combo Helpers

    private func modifierFlag(for keyCode: Int) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        case 63: return .function
        default: return nil
        }
    }

    private func modifierComboModifiers(for keyCode: Int, flags: NSEvent.ModifierFlags) -> UInt64 {
        var clean = flags.intersection([.command, .shift, .option, .control, .function])
        if let own = modifierFlag(for: keyCode) {
            clean.remove(own)
        }
        return clean.isEmpty ? 0 : UInt64(clean.rawValue)
    }

    // MARK: - Key Display Name

    static func keyDisplayName(keyCode: Int, modifiers: UInt64?) -> String {
        let mods = modifiers ?? 0
        var parts: [String] = []
        if mods != 0 {
            let flags = NSEvent.ModifierFlags(rawValue: UInt(mods))
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }
            if flags.contains(.function) { parts.append("Fn") }
        }
        let keyName = singleKeyName(keyCode)
        if parts.last != keyName {
            parts.append(keyName)
        }
        return parts.joined(separator: "+")
    }

    static func singleKeyName(_ keyCode: Int) -> String {
        switch keyCode {
        // Modifier keys
        case 54, 55: return "⌘"
        case 56, 60: return "⇧"
        case 58, 61: return "⌥"
        case 59, 62: return "⌃"
        case 63: return "Fn"

        // Special keys
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 76: return "Enter"
        case 117: return "Forward Delete"

        // Arrows
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        // F-keys
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"

        default:
            return ucKeyTranslateName(keyCode) ?? "Key \(keyCode)"
        }
    }

    // MARK: - UCKeyTranslate Fallback

    private static func ucKeyTranslateName(_ keyCode: Int) -> String? {
        guard let source = (TISCopyCurrentASCIICapableKeyboardInputSource() ?? TISCopyCurrentKeyboardInputSource())?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutPtr, to: CFData.self)
        let layout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
