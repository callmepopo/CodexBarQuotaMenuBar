import AppKit
import Darwin
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let launchJobLabel = "local.CodexBarQuotaMenuBar"
    private var instanceLock: SingleInstanceLock?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let viewModel = QuotaViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let instanceLock = SingleInstanceLock.acquire() else {
            NSApp.terminate(nil)
            return
        }

        self.instanceLock = instanceLock
        NSApp.setActivationPolicy(.accessory)
        setupPopover()
        setupStatusItem()
        viewModel.start()
    }

    private func setupPopover() {
        let hostingController = NSHostingController(rootView: QuotaView(viewModel: viewModel))
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 680)
        self.popover = popover

        viewModel.onStateChange = { [weak popover, weak hostingController] in
            DispatchQueue.main.async {
                guard let popover, let hostingController else {
                    return
                }
                hostingController.view.layoutSubtreeIfNeeded()
                let fittingSize = hostingController.view.fittingSize
                popover.contentSize = NSSize(
                    width: max(340, ceil(fittingSize.width)),
                    height: max(180, ceil(fittingSize.height))
                )
            }
        }
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(contentsOfFile: "/Applications/CodexBar.app/Contents/Resources/ProviderIcon-codex.svg") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "CodexBar DIY")
        }

        button.toolTip = "CodexBar DIY 额度"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        togglePopover(sender)
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            viewModel.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "刷新", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitFromMenu), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshFromMenu() {
        viewModel.refresh()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.removeLaunchJob()
        return .terminateNow
    }

    private static func removeLaunchJob() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["remove", launchJobLabel]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

private final class SingleInstanceLock {
    private let fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    static func acquire() -> SingleInstanceLock? {
        let fileManager = FileManager.default
        let supportURL = fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexBarQuotaMenuBar")

        do {
            try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let lockPath = supportURL.appendingPathComponent("app.lock").path
        let fileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return nil
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            return nil
        }

        ftruncate(fileDescriptor, 0)
        let pidText = "\(getpid())\n"
        pidText.withCString {
            _ = write(fileDescriptor, $0, strlen($0))
        }

        return SingleInstanceLock(fileDescriptor: fileDescriptor)
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}
