import Cocoa
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var updateTimer: Timer?
    
    // Shared services for menu bar monitor
    private let monitor = SystemMonitorService()
    private let batteryService = BatteryHealthService()
    private let adEngine = AdEngineService()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBarStatusItem()
        startMenuBarUpdater()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func setupMenuBarStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.action = #selector(togglePopover(_:))
        button.target = self
        updateStatusBarTitle()
        
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 290, height: 320)
        pop.behavior = .transient
        
        let contentView = MenuBarPopoverView(
            monitor: monitor,
            batteryService: batteryService,
            adEngine: adEngine,
            onOpenMainWindow: { [weak self] in
                self?.openMainWindow()
            }
        )
        pop.contentViewController = NSHostingController(rootView: contentView)
        self.popover = pop
    }
    
    private func startMenuBarUpdater() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusBarTitle()
            }
        }
    }
    
    private func updateStatusBarTitle() {
        guard let button = statusItem?.button else { return }
        let showCpu = UserDefaults.standard.object(forKey: "showCpuInMenuBar") as? Bool ?? true
        let showBatt = UserDefaults.standard.object(forKey: "showBatteryInMenuBar") as? Bool ?? true
        
        let cpu = Int(round(monitor.cpuUsagePercent))
        let batt = batteryService.batteryInfo.stateOfCharge
        let bolt = batteryService.batteryInfo.isCharging ? "⚡️" : ""
        
        var parts: [String] = []
        if showBatt {
            parts.append("\(bolt)\(batt)%")
        }
        if showCpu {
            parts.append("\(cpu)% CPU")
        }
        
        button.title = parts.isEmpty ? "" : parts.joined(separator: " • ")
        button.image = NSImage(systemSymbolName: "bolt.shield.fill", accessibilityDescription: "CovaMac")
        button.imagePosition = parts.isEmpty ? .imageOnly : .imageLeading
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
    
    public func openMainWindow() {
        popover?.performClose(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Find main window, skipping status item/popover auxiliary windows
        for window in NSApplication.shared.windows {
            if window.canBecomeMain || (window.level == .normal && !window.className.contains("Popover")) {
                window.makeKeyAndOrderFront(nil)
                window.deminiaturize(nil)
                return
            }
        }
    }
}
