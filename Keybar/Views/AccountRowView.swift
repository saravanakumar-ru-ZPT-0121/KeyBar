import SwiftUI
import AppKit

/// A single row in the menu bar dropdown: issuer/label, masked account name,
/// the live current code, and a countdown ring. Clicking anywhere on the row
/// (or the dedicated copy button) copies the current code immediately.
struct AccountRowView: View {
    let account: Account
    @ObservedObject var accountStore: AccountStore

    @State private var didCopy = false
    @State private var isEditing = false
    @State private var cachedSecret: Data?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = currentCode(at: context.date)
            let progress = TOTPEngine.progress(period: account.period, date: context.date)
            let secondsRemaining = Int(TOTPEngine.timeRemaining(period: account.period, date: context.date).rounded(.up))

            HStack(spacing: 12) {
                CountdownRing(progress: progress, secondsRemaining: secondsRemaining)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(account.maskedAccountName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(formattedCode(code))
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()

                copyButton(code: code)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { copy(code: code) }
            .contextMenu {
                Button("Edit…") { isEditing = true }
                Button("Delete", role: .destructive) {
                    accountStore.deleteAccount(account.id)
                }
            }
        }
        .task { loadSecret() }
        .sheet(isPresented: $isEditing) {
            AddAccountView(accountStore: accountStore, editingAccount: account)
        }
    }

    private func currentCode(at date: Date) -> String {
        guard let secret = cachedSecret else { return "······" }
        return TOTPEngine.generate(
            secret: secret,
            algorithm: account.algorithm,
            digits: account.digits,
            period: account.period,
            date: date
        )
    }

    private func loadSecret() {
        cachedSecret = try? accountStore.secret(for: account.id)
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count > 3 else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<mid]) \(code[mid...])"
    }

    private func copyButton(code: String) -> some View {
        Button {
            copy(code: code)
        } label: {
            Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundStyle(didCopy ? .green : .secondary)
                .animation(.easeInOut(duration: 0.15), value: didCopy)
        }
        .buttonStyle(.plain)
        .help("Copy code")
    }

    private func copy(code: String) {
        guard cachedSecret != nil else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)

        didCopy = true
        NotificationCenter.default.post(name: .keybarDidCopyCode, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            didCopy = false
        }
    }
}

extension Notification.Name {
    /// Posted immediately after a code is copied to the clipboard, so the
    /// popover can be dismissed right away.
    static let keybarDidCopyCode = Notification.Name("com.keybar.didCopyCode")
}
