import AppKit
import SwiftUI

@MainActor
final class QuotaViewModel: ObservableObject {
    @Published private(set) var state = WidgetState(message: "正在读取数据")
    @Published private(set) var switchMessage: String?
    var onStateChange: (() -> Void)?

    private let store = DataStore()
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        do {
            state = try store.load()
        } catch {
            if state.accounts.isEmpty {
                state = WidgetState(accounts: [], lastUpdated: state.lastUpdated, stale: true, message: "数据未更新")
            } else {
                state.stale = true
                state.message = "数据未更新"
            }
        }

        onStateChange?()
    }

    func switchAccount(_ account: AccountQuota) {
        guard let sourceAuthPath = account.switchSourceAuthPath else {
            switchMessage = "无可用授权"
            onStateChange?()
            return
        }

        if account.isActive {
            switchMessage = "当前账号已在使用"
            onStateChange?()
            return
        }

        do {
            try store.switchCodexAccount(sourceAuthPath: sourceAuthPath)
            switchMessage = "切换成功，重开终端生效"
            refresh()
        } catch {
            switchMessage = error.localizedDescription
            onStateChange?()
        }
    }
}

struct QuotaView: View {
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.state.accounts.isEmpty {
                Text(viewModel.state.message ?? "暂无数据")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            } else {
                ForEach(Array(viewModel.state.accounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.16))
                            .padding(.horizontal, 2)
                            .padding(.vertical, 8)
                    }
                    AccountQuotaView(account: account) {
                        viewModel.switchAccount(account)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 340)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.09),
                        Color(red: 0.12, green: 0.12, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.92)

                Color.white.opacity(0.04)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("CodexBar 额度")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            if let switchMessage = viewModel.switchMessage {
                Text(switchMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(switchMessage.contains("成功") ? .green : .orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            } else if viewModel.state.stale {
                Text("数据未更新")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            } else if let lastUpdated = viewModel.state.lastUpdated {
                Text(lastUpdated, format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.7))
            .help("刷新")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.7))
            .help("退出")
        }
    }
}

private struct AccountQuotaView: View {
    let account: AccountQuota
    let onSwitch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    ProviderLogo(provider: account.provider, color: providerColor)

                    Text(account.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subscription = account.subscription {
                        Text(subscription)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(subscriptionColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(subscriptionColor.opacity(0.16))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(subscriptionColor.opacity(0.36), lineWidth: 1)
                            }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(account.provider)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(providerColor)

                    if account.provider.lowercased() == "codex", account.switchSourceAuthPath != nil {
                        Button {
                            onSwitch()
                        } label: {
                            Text(account.isActive ? "Active" : "Switch")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(account.isActive ? Color.green : Color.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background((account.isActive ? Color.green : providerColor).opacity(0.18))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke((account.isActive ? Color.green : providerColor).opacity(0.36), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(account.isActive)
                        .help(account.isActive ? "当前 Codex CLI 账号" : "切换 Codex CLI 到此账号")
                    }
                }
            }

            if let status = account.status {
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            if account.windows.isEmpty {
                Text("暂无额度数据")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(account.windows) { window in
                    QuotaWindowView(window: window)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var providerColor: Color {
        account.provider.lowercased() == "claude"
            ? Color(red: 0.63, green: 0.46, blue: 0.28)
            : Color(red: 0.20, green: 0.65, blue: 0.88)
    }

    private var subscriptionColor: Color {
        switch account.subscription?.lowercased() {
        case "team", "enterprise":
            return Color(red: 0.40, green: 0.78, blue: 1.00)
        case "pro":
            return Color(red: 0.74, green: 0.60, blue: 1.00)
        case "plus":
            return Color(red: 0.36, green: 0.90, blue: 0.58)
        default:
            return Color(red: 0.72, green: 0.72, blue: 0.76)
        }
    }
}

private struct ProviderLogo: View {
    let provider: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(logoBackground)
                .frame(width: 28, height: 28)

            if let image = ProviderLogoImage.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else if provider.lowercased() == "claude" {
                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
        .help("\(provider) 标识")
    }

    private var logoBackground: Color {
        provider.lowercased() == "claude"
            ? Color(red: 0.70, green: 0.43, blue: 0.32)
            : Color(red: 0.43, green: 0.47, blue: 1.00)
    }
}

private struct QuotaWindowView: View {
    let window: QuotaWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(windowTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 42, alignment: .leading)

                UsageBar(percent: clampedPercent, color: progressColor)

                Text("\(clampedPercent)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(progressColor)
                    .frame(width: 38, alignment: .trailing)
            }

            if window.isNotStarted {
                Text("Not started yet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Text("Resets in \(resetRemainingText)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(resetAbsoluteText)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.09),
                    Color.white.opacity(0.06)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var clampedPercent: Int {
        min(max(window.displayUsedPercent, 0), 100)
    }

    private var windowTitle: String {
        switch window.windowMinutes {
        case 300:
            return "5小时"
        case 10080:
            return "1周"
        default:
            return "\(window.windowMinutes)分"
        }
    }

    private var progressColor: Color {
        switch clampedPercent {
        case 0..<50:
            return Color(red: 0.20, green: 0.78, blue: 0.42)
        case 50..<80:
            return Color(red: 0.98, green: 0.67, blue: 0.22)
        default:
            return Color(red: 0.96, green: 0.26, blue: 0.24)
        }
    }

    private var resetDate: Date? {
        ResetDateParser.date(from: window.resetsAt?.value)
    }

    private var resetRemainingText: String {
        guard let resetDate else {
            return "--"
        }

        let seconds = max(0, Int(resetDate.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        switch window.windowMinutes {
        case 300:
            return "\(seconds / 3_600)h\(minutes)m"
        case 10080:
            return "\(days)d\(hours)h"
        default:
            if days > 0 {
                return "\(days)d\(hours)h"
            }
            return "\(hours)h\(minutes)m"
        }
    }

    private var resetAbsoluteText: String {
        guard let resetDate else {
            return window.resetDescription ?? "--"
        }

        let formatter = DateFormatter()
        formatter.timeZone = .current

        switch window.windowMinutes {
        case 300:
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm"
        case 10080:
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE H:mm"
        default:
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 H:mm"
        }

        return formatter.string(from: resetDate)
    }
}

private struct UsageBar: View {
    let percent: Int
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.78), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth(in: proxy.size.width))
                    .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("使用量 \(percent)%")
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard percent > 0 else {
            return 0
        }

        return max(6, totalWidth * CGFloat(percent) / 100)
    }
}

private enum ResetDateParser {
    static func date(from value: String?) -> Date? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        let fractionalISOFormatter = ISO8601DateFormatter()
        fractionalISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: raw) ?? fractionalISOFormatter.date(from: raw) {
            return date
        }

        if let seconds = Double(raw) {
            return date(fromSeconds: seconds)
        }

        return nil
    }

    private static func date(fromSeconds seconds: Double) -> Date {
        let referenceDate = Date(timeIntervalSinceReferenceDate: seconds)
        let unixDate = Date(timeIntervalSince1970: seconds)
        let now = Date()

        if referenceDate >= now, unixDate < now {
            return referenceDate
        }

        if unixDate >= now, referenceDate < now {
            return unixDate
        }

        if abs(referenceDate.timeIntervalSince(now)) < abs(unixDate.timeIntervalSince(now)) {
            return referenceDate
        }

        return unixDate
    }
}

private enum ProviderLogoImage {
    static func image(for provider: String) -> NSImage? {
        let filename = provider.lowercased() == "claude" ? "ProviderIcon-claude.svg" : "ProviderIcon-codex.svg"
        let paths = [
            "/Applications/CodexBar.app/Contents/Resources/\(filename)",
            "/Applications/CodexBar.app/Contents/Resources/CodexBar_CodexBar.bundle/\(filename)"
        ]

        for path in paths {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }

        return nil
    }
}
