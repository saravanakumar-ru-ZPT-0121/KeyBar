import SwiftUI

/// Manual entry form for adding (or editing) an account, plus an entry point
/// into QR-code import.
struct AddAccountView: View {
    @ObservedObject var accountStore: AccountStore
    var editingAccount: Account?

    @Environment(\.dismiss) private var dismiss

    @State private var issuer = ""
    @State private var accountName = ""
    @State private var secret = ""
    @State private var algorithm: TOTPAlgorithm = .sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var showingQRImport = false
    @State private var errorMessage: String?

    private var isEditing: Bool { editingAccount != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Account" : "Add Account")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Section {
                    TextField("Issuer (e.g. GitHub)", text: $issuer)
                    TextField("Account name (e.g. jane@doe.com)", text: $accountName)
                    if !isEditing {
                        SecureField("Base32 secret", text: $secret)
                    }
                }

                Section("Options") {
                    Picker("Algorithm", selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases) { algo in
                            Text(algo.displayName).tag(algo)
                        }
                    }
                    Picker("Digits", selection: $digits) {
                        Text("6").tag(6)
                        Text("8").tag(8)
                    }
                    Stepper("Period: \(period)s", value: $period, in: 15...60, step: 15)
                }

                if !isEditing {
                    Section {
                        Button {
                            showingQRImport = true
                        } label: {
                            Label("Import from QR Code…", systemImage: "qrcode.viewfinder")
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding([.horizontal, .bottom], 16)
        }
        .frame(width: 360, height: 440)
        .onAppear(perform: populateIfEditing)
        .sheet(isPresented: $showingQRImport) {
            QRImportView { imported in
                apply(imported)
                showingQRImport = false
            }
        }
    }

    private var isValid: Bool {
        guard !accountName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isEditing { return true }
        return Base32.decode(secret) != nil
    }

    private func populateIfEditing() {
        guard let account = editingAccount else { return }
        issuer = account.issuer
        accountName = account.accountName
        algorithm = account.algorithm
        digits = account.digits
        period = account.period
    }

    private func apply(_ imported: ImportedTOTPAccount) {
        issuer = imported.issuer
        accountName = imported.accountName
        secret = imported.base32Secret
        algorithm = imported.algorithm
        digits = imported.digits
        period = imported.period
    }

    private func save() {
        do {
            if let account = editingAccount {
                var updated = account
                updated.issuer = issuer
                updated.accountName = accountName
                updated.algorithm = algorithm
                updated.digits = digits
                updated.period = period
                accountStore.updateMetadata(updated)
            } else {
                guard let secretData = Base32.decode(secret) else {
                    errorMessage = "That doesn't look like a valid Base32 secret."
                    return
                }
                try accountStore.addAccount(
                    issuer: issuer,
                    accountName: accountName,
                    secret: secretData,
                    algorithm: algorithm,
                    digits: digits,
                    period: period
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
