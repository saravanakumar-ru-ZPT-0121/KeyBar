import SwiftUI
import AppKit

/// The entire menu bar dropdown: search field, account list, add button, and
/// the global shortcut recorder. Hosted inside an `NSPopover` by `AppDelegate`.
struct MenuBarView: View {
    @EnvironmentObject var accountStore: AccountStore
    @ObservedObject var appSettings: AppSettings

    @State private var searchText = ""
    @State private var isAddingAccount = false
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled

    private var showsSearchField: Bool {
        accountStore.accounts.count > 5
    }

    private var filteredAccounts: [Account] {
        guard showsSearchField, !searchText.isEmpty else { return accountStore.accounts }
        return accountStore.accounts.filter {
            $0.issuer.localizedCaseInsensitiveContains(searchText) ||
            $0.accountName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if showsSearchField {
                searchField
                Divider()
            }

            Group {
                if accountStore.accounts.isEmpty {
                    emptyState
                } else if filteredAccounts.isEmpty {
                    noResultsState
                } else {
                    accountList
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            footer
        }
        .frame(width: 340, height: 440)
        .background(.regularMaterial)
        .onAppear { launchAtLogin = LaunchAtLoginManager.isEnabled }
        .sheet(isPresented: $isAddingAccount) {
            AddAccountView(accountStore: accountStore)
        }
    }

    private var header: some View {
        HStack {
            Text("Keybar")
                .font(.headline)
            Spacer()
            Button {
                isAddingAccount = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Add account")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search accounts", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var accountList: some View {
        List {
            ForEach(filteredAccounts) { account in
                AccountRowView(account: account, accountStore: accountStore)
                    .listRowInsets(EdgeInsets())
            }
            .onMove(perform: searchText.isEmpty ? moveAccounts : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func moveAccounts(from source: IndexSet, to destination: Int) {
        accountStore.move(fromOffsets: source, toOffset: destination)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No accounts yet")
                .font(.subheadline)
            Text("Click + to add your first account.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        Text("No matching accounts")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShortcutRecorderView(combo: $appSettings.shortcut)

            HStack {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { newValue in
                        launchAtLogin = LaunchAtLoginManager.setEnabled(newValue) ? newValue : LaunchAtLoginManager.isEnabled
                    }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
