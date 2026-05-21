import Foundation

struct ProviderState: Decodable {
    let enabledProviders: [String]
    let entries: [ProviderEntry]
}

struct ProviderEntry: Decodable {
    let provider: String
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
    let updatedAt: String?
}

struct ManagedCodexAccounts: Decodable {
    let accounts: [ManagedCodexAccount]
}

struct ManagedCodexAccount: Decodable {
    let id: String
    let email: String?
    let managedHomePath: String?
    let providerAccountID: String?
    let workspaceLabel: String?
}

struct CodexSnapshotStore: Decodable {
    let records: [CodexSnapshotRecord]
}

struct ClaudeHistoryStore: Decodable {
    let accounts: [String: [ClaudeWindowHistory]]
}

struct CodexHistoryStore: Decodable {
    let accounts: [String: [CodexWindowHistory]]
}

struct ClaudeWindowHistory: Decodable {
    let name: String?
    let windowMinutes: Int
    let entries: [ClaudeHistoryEntry]
}

struct CodexWindowHistory: Decodable {
    let name: String?
    let windowMinutes: Int
    let entries: [CodexHistoryEntry]
}

struct ClaudeHistoryEntry: Decodable {
    let capturedAt: String?
    let resetsAt: String?
    let usedPercent: Int
}

struct CodexHistoryEntry: Decodable {
    let capturedAt: String?
    let resetsAt: String?
    let usedPercent: Int
}

struct CodexSnapshotRecord: Decodable {
    let id: String
    let snapshot: CodexSnapshot?
}

struct CodexSnapshot: Decodable {
    let accountEmail: String?
    let loginMethod: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
    let updatedAt: FlexibleString?
}

struct QuotaWindow: Decodable, Identifiable {
    var id: Int { windowMinutes }

    let usedPercent: Int
    let resetDescription: String?
    let resetsAt: FlexibleString?
    let windowMinutes: Int
    let displayUsedPercent: Int
    let isNotStarted: Bool

    init(
        usedPercent: Int,
        resetDescription: String?,
        resetsAt: FlexibleString?,
        windowMinutes: Int,
        displayUsedPercent: Int? = nil,
        isNotStarted: Bool = false
    ) {
        self.usedPercent = usedPercent
        self.resetDescription = resetDescription
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes
        self.displayUsedPercent = displayUsedPercent ?? usedPercent
        self.isNotStarted = isNotStarted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decode(Int.self, forKey: .usedPercent)
        resetDescription = try container.decodeIfPresent(String.self, forKey: .resetDescription)
        resetsAt = try container.decodeIfPresent(FlexibleString.self, forKey: .resetsAt)
        windowMinutes = try container.decode(Int.self, forKey: .windowMinutes)
        displayUsedPercent = usedPercent
        isNotStarted = false
    }

    func markedNotStarted(displayUsedPercent: Int? = nil) -> QuotaWindow {
        QuotaWindow(
            usedPercent: usedPercent,
            resetDescription: resetDescription,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes,
            displayUsedPercent: displayUsedPercent ?? self.displayUsedPercent,
            isNotStarted: true
        )
    }

    private enum CodingKeys: String, CodingKey {
        case usedPercent
        case resetDescription
        case resetsAt
        case windowMinutes
    }
}

struct FlexibleString: Decodable {
    let value: String

    init(value: String?) {
        self.value = value ?? ""
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            value = ""
        }
    }
}

struct AccountQuota: Identifiable {
    let id: String
    let provider: String
    let displayName: String
    let subscription: String?
    let windows: [QuotaWindow]
    let updatedAt: String?
    let status: String?
    let switchSourceAuthPath: String?
    let isActive: Bool
}

struct WidgetState {
    var accounts: [AccountQuota] = []
    var lastUpdated: Date?
    var stale = false
    var message: String?
}
