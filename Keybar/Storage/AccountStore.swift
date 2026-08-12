import Foundation
import Combine

/// Owns the in-memory list of accounts, persists non-secret metadata to a local
/// JSON file in Application Support, and delegates all secret storage and
/// retrieval to the Keychain. The raw secret never touches this file.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []

    private let keychain = KeychainStore()
    private let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? AccountStore.defaultStoreURL()
        load()
    }

    static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("Keybar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("accounts.json")
    }

    // MARK: - CRUD

    @discardableResult
    func addAccount(
        issuer: String,
        accountName: String,
        secret: Data,
        algorithm: TOTPAlgorithm,
        digits: Int,
        period: Int
    ) throws -> Account {
        let account = Account(
            issuer: issuer,
            accountName: accountName,
            algorithm: algorithm,
            digits: digits,
            period: period,
            sortOrder: (accounts.map(\.sortOrder).max() ?? -1) + 1
        )
        try keychain.saveSecret(secret, for: account.id)
        accounts.append(account)
        persist()
        return account
    }

    func updateMetadata(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        persist()
    }

    func updateSecret(_ secret: Data, for accountID: UUID) throws {
        try keychain.saveSecret(secret, for: accountID)
    }

    func deleteAccount(_ accountID: UUID) {
        accounts.removeAll { $0.id == accountID }
        try? keychain.deleteSecret(for: accountID)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        accounts.move(fromOffsets: source, toOffset: destination)
        for index in accounts.indices {
            accounts[index].sortOrder = index
        }
        persist()
    }

    func secret(for accountID: UUID) throws -> Data {
        try keychain.loadSecret(for: accountID)
    }

    // MARK: - Persistence (metadata only — secrets never leave the Keychain)

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        guard let decoded = try? JSONDecoder().decode([Account].self, from: data) else { return }
        accounts = decoded.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
