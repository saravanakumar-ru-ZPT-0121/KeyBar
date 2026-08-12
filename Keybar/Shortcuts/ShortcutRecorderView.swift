import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A small control that displays the current global shortcut and lets the user
/// record a new one by pressing a key combination.
struct ShortcutRecorderView: View {
    @Binding var combo: KeyCombo
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text("Open Keybar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Press a key…" : combo.displayString)
                    .font(.caption.monospaced())
                    .frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return nil }
            combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
