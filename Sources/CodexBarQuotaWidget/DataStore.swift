import Foundation

final class DataStore {
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    private var homeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
    }

    private var widgetSnapshotURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Group Containers/Y5PE65HELJ.com.steipete.codexbar/widget-snapshot.json")
    }

    private var managedCodexAccountsURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/CodexBar/managed-codex-accounts.json")
    }

    private var codexSnapshotsURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/CodexBar/codex-account-snapshots.json")
    }

    private var codexHistoryURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/com.steipete.codexbar/history/codex.json")
    }

    private var claudeHistoryURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/com.steipete.codexbar/history/claude.json")
    }

    private var activeCodexAuthURL: URL {
        homeDirectory.appendingPathComponent(".codex/auth.json")
    }

    private var authBackupDirectoryURL: URL {
        homeDirectory.appendingPathComponent(".codex/auth-backups")
    }

    func load() throws -> WidgetState {
        let providerState = try decode(ProviderState.self, from: widgetSnapshotURL)
        let enabled = Set(providerState.enabledProviders.map { $0.lowercased() })
        var accounts: [AccountQuota] = []

        if enabled.contains("codex") {
            accounts.append(contentsOf: loadCodexAccounts())
        }

        if enabled.contains("claude") {
            let providerEntries = loadProviderEntries(named: "claude", from: providerState)
            accounts.append(contentsOf: providerEntries.isEmpty ? loadClaudeHistory() : providerEntries)
        }

        if accounts.isEmpty {
            return WidgetState(accounts: [], lastUpdated: Date(), stale: false, message: "暂无启用账号")
        }

        return WidgetState(accounts: accounts, lastUpdated: Date(), stale: false, message: nil)
    }

    private func loadCodexAccounts() -> [AccountQuota] {
        guard let accountStore = try? decode(ManagedCodexAccounts.self, from: managedCodexAccountsURL) else {
            return []
        }

        let snapshotStore = try? decode(CodexSnapshotStore.self, from: codexSnapshotsURL)
        let historyStore = try? decode(CodexHistoryStore.self, from: codexHistoryURL)
        let activeEmail = codexAuthIdentity(at: activeCodexAuthURL).email?.lowercased()
        var snapshotsByKey: [String: CodexSnapshot] = [:]

        for record in snapshotStore?.records ?? [] {
            guard let snapshot = record.snapshot else {
                continue
            }

            snapshotsByKey[record.id.lowercased()] = snapshot
            if let email = snapshot.accountEmail?.lowercased(), !email.isEmpty {
                snapshotsByKey[email] = snapshot
            }
        }

        return accountStore.accounts.map { account in
            let lookupKeys = [account.email, account.id].compactMap { $0?.lowercased() }
            let snapshot = lookupKeys.lazy.compactMap { snapshotsByKey[$0] }.first
            let sourceAuthPath = account.managedHomePath.map {
                URL(fileURLWithPath: $0).appendingPathComponent("auth.json").path
            }
            let authIdentity = sourceAuthPath.map { codexAuthIdentity(at: URL(fileURLWithPath: $0)) }
            let authEmail = authIdentity.flatMap { $0.email }
            let authPlan = authIdentity.flatMap { $0.plan }
            let displayEmail = account.email ?? snapshot?.accountEmail ?? authEmail
            let isActive = displayEmail?.lowercased() == activeEmail

            if let snapshot {
                let windows = normalizeCodexWindows([snapshot.primary, snapshot.secondary].compactMap { $0 })
                if !windows.isEmpty {
                    return AccountQuota(
                        id: "codex-\(account.id)",
                        provider: "Codex",
                        displayName: Privacy.maskedEmail(displayEmail),
                        subscription: displaySubscription(snapshot.loginMethod ?? authPlan),
                        windows: windows,
                        updatedAt: snapshot.updatedAt?.value,
                        status: nil,
                        switchSourceAuthPath: sourceAuthPath,
                        isActive: isActive
                    )
                }
            }

            let history = loadCodexHistory(for: account, from: historyStore)
            return AccountQuota(
                id: "codex-\(account.id)",
                provider: "Codex",
                displayName: Privacy.maskedEmail(displayEmail),
                subscription: displaySubscription(authPlan),
                windows: normalizeCodexWindows(history?.windows ?? []),
                updatedAt: history?.updatedAt,
                status: history == nil ? "需重新认证" : "历史数据 / 需重新认证",
                switchSourceAuthPath: sourceAuthPath,
                isActive: isActive
            )
        }
    }

    func switchCodexAccount(sourceAuthPath: String) throws {
        let sourceURL = URL(fileURLWithPath: sourceAuthPath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DataStoreError.missingManagedAuth
        }

        let codexHomeURL = activeCodexAuthURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: authBackupDirectoryURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: activeCodexAuthURL.path) {
            let backupURL = authBackupDirectoryURL
                .appendingPathComponent("auth-\(backupTimestamp())-\(UUID().uuidString).json")
            try fileManager.copyItem(at: activeCodexAuthURL, to: backupURL)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
        }

        let data = try Data(contentsOf: sourceURL)
        let temporaryURL = codexHomeURL.appendingPathComponent(".auth.json.\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)

        if fileManager.fileExists(atPath: activeCodexAuthURL.path) {
            _ = try fileManager.replaceItemAt(
                activeCodexAuthURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: []
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: activeCodexAuthURL)
        }

        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: activeCodexAuthURL.path)
    }

    private func loadProviderEntries(named provider: String, from state: ProviderState) -> [AccountQuota] {
        state.entries
            .filter { $0.provider.lowercased() == provider.lowercased() }
            .compactMap { entry in
                let windows = [entry.primary, entry.secondary].compactMap { $0 }
                guard !windows.isEmpty else {
                    return nil
                }

                let displayName = provider.lowercased() == "claude" ? "Claude 账号" : provider.capitalized
                return AccountQuota(
                    id: "provider-\(provider)",
                    provider: provider.capitalized,
                    displayName: displayName,
                    subscription: provider.lowercased() == "claude" ? "Claude" : nil,
                    windows: windows,
                    updatedAt: entry.updatedAt,
                    status: nil,
                    switchSourceAuthPath: nil,
                    isActive: false
                )
            }
    }

    private func loadClaudeHistory() -> [AccountQuota] {
        guard let historyStore = try? decode(ClaudeHistoryStore.self, from: claudeHistoryURL) else {
            return []
        }

        return historyStore.accounts.sorted { $0.key < $1.key }.compactMap { key, histories in
            let windows = histories.compactMap { history -> QuotaWindow? in
                guard let latest = history.entries.last else {
                    return nil
                }

                return QuotaWindow(
                    usedPercent: latest.usedPercent,
                    resetDescription: formatResetDescription(latest.resetsAt),
                    resetsAt: FlexibleString(value: latest.resetsAt),
                    windowMinutes: history.windowMinutes
                )
            }

            guard !windows.isEmpty else {
                return nil
            }

            let latestCapture = histories.compactMap { $0.entries.last?.capturedAt }.sorted().last
            return AccountQuota(
                id: "claude-\(key)",
                provider: "Claude",
                displayName: "Claude 账号",
                subscription: "Claude",
                windows: windows.sorted { $0.windowMinutes < $1.windowMinutes },
                updatedAt: latestCapture,
                status: nil,
                switchSourceAuthPath: nil,
                isActive: false
            )
        }
    }

    private func loadCodexHistory(
        for account: ManagedCodexAccount,
        from historyStore: CodexHistoryStore?
    ) -> (windows: [QuotaWindow], updatedAt: String?)? {
        guard let historyStore else {
            return nil
        }

        let keyCandidates = [
            account.providerAccountID.map { "codex:v1:provider-account:\($0)" },
            account.email,
            account.id
        ].compactMap { $0?.lowercased() }

        guard let histories = keyCandidates.lazy.compactMap({ historyStore.accounts[$0] }).first else {
            return nil
        }

        let windows = histories.compactMap { history -> QuotaWindow? in
            guard let latest = history.entries.last else {
                return nil
            }

            return QuotaWindow(
                usedPercent: latest.usedPercent,
                resetDescription: formatResetDescription(latest.resetsAt),
                resetsAt: FlexibleString(value: latest.resetsAt),
                windowMinutes: history.windowMinutes
            )
        }

        guard !windows.isEmpty else {
            return nil
        }

        let latestCapture = histories.compactMap { $0.entries.last?.capturedAt }.sorted().last
        return (windows.sorted { $0.windowMinutes < $1.windowMinutes }, latestCapture)
    }

    private func normalizeCodexWindows(_ windows: [QuotaWindow]) -> [QuotaWindow] {
        guard isNotStartedCodexUsage(windows) else {
            return windows
        }

        return windows.map { window in
            window.markedNotStarted(displayUsedPercent: window.windowMinutes == 300 ? 0 : nil)
        }
    }

    private func isNotStartedCodexUsage(_ windows: [QuotaWindow]) -> Bool {
        let fiveHour = windows.first { $0.windowMinutes == 300 }
        let oneWeek = windows.first { $0.windowMinutes == 10_080 }

        return fiveHour.map { $0.usedPercent <= 1 } == true
            && oneWeek.map { $0.usedPercent == 0 } == true
    }

    private func formatResetDescription(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return value
        }

        let calendar = Calendar.current
        let output = DateFormatter()
        output.locale = Locale(identifier: "zh_CN")
        output.timeZone = .current
        output.dateFormat = calendar.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
        return output.string(from: date)
    }

    private func displaySubscription(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        switch value.lowercased() {
        case "pro":
            return "Pro"
        case "plus":
            return "Plus"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return value.prefix(1).uppercased() + value.dropFirst()
        }
    }

    private func codexAuthIdentity(at url: URL) -> (email: String?, plan: String?) {
        guard
            let auth = try? decode(CodexAuth.self, from: url),
            let idToken = auth.tokens?.idToken,
            let payload = decodeJWTClaims(from: idToken)
        else {
            return (nil, nil)
        }

        let email = payload["email"] as? String
        let authClaims = payload["https://api.openai.com/auth"] as? [String: Any]
        let plan = authClaims?["chatgpt_plan_type"] as? String
        return (email, plan)
    }

    private func decodeJWTClaims(from token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count > 1 else {
            return nil
        }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data),
            let claims = object as? [String: Any]
        else {
            return nil
        }

        return claims
    }

    private func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
}

private struct CodexAuth: Decodable {
    let tokens: Tokens?

    struct Tokens: Decodable {
        let idToken: String?

        private enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
        }
    }
}

private enum DataStoreError: LocalizedError {
    case missingManagedAuth

    var errorDescription: String? {
        switch self {
        case .missingManagedAuth:
            return "CodexBar 保存的账号授权文件不存在"
        }
    }
}
