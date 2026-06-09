import SwiftUI
import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var calendarPopover: NSPopover!
    private var settingsWindow: NSWindow?
    private var detailWindow: NSWindow?
    let settings = AppSettings()

    private var refreshTimer: Timer?
    private var lastRenderedKey: String = ""

    // 全局事件监视：用于"点别处时关掉设置/详情窗口"
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 不在 Dock 显示，纯状态栏 app
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupCalendarPopover()
        setupSettingsWindow()

        refreshStatusItem(force: true)
        scheduleTimer()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
        }
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.image = StatusBarIcon.makeImage()
            button.imagePosition = .imageOnly
        }
    }

    private func scheduleTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshStatusItem(force: false)
        }
    }

    private func refreshStatusItem(force: Bool) {
        guard let button = statusItem.button else { return }
        let day = Calendar.current.component(.day, from: Date())
        let isDark = isSystemDarkMode()
        let key = "\(day)|\(isDark)"
        if !force && key == lastRenderedKey { return }
        lastRenderedKey = key
        button.image = StatusBarIcon.makeImage(day: day)
    }

    private func isSystemDarkMode() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: - 月历 Popover

    private func setupCalendarPopover() {
        let popover = NSPopover()
        popover.behavior = .transient   // 关键：点别处自动消失
        popover.animates = true
        popover.appearance = nil        // 跟随系统
        // 内容高度由 SwiftUI 自适应；宽度固定
        popover.contentSize = NSSize(width: 320, height: 360)

        let view = CalendarPanelView(
            settings: settings,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenDetail: { [weak self] date in self?.openDetail(for: date) },
            onClose: { [weak self] in
                self?.calendarPopover.performClose(nil)
            }
        )
        popover.contentViewController = NSHostingController(rootView: view)
        self.calendarPopover = popover
    }

    // MARK: - 设置窗口

    private func setupSettingsWindow() {
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 480),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        win.title = "小历 设置"
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.appearance = nil   // 跟随系统
        win.center()

        win.contentView = NSHostingView(rootView: MainPanelView(
            settings: settings,
            onClose: { [weak win] in win?.orderOut(nil) }
        ))

        self.settingsWindow = win
    }

    private func openSettings() {
        // 关键：开设置时把月历 popover 关掉
        calendarPopover.performClose(nil)

        guard let win = settingsWindow else { return }
        // 定位：屏幕中央（也可以定位到状态栏按钮附近）
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 监听"点别处关设置"
        installGlobalMonitor(for: win)
    }

    // MARK: - 日期详情窗口

    private func openDetail(for date: Date) {
        // 弹详情时月历可以保留（很多 macOS app 都这样），但也可以关掉
        // 这里保留月历，方便继续翻日期
        if let old = detailWindow {
            old.orderOut(nil)
        }
        let style: NSWindow.StyleMask = [.titled, .closable, .resizable]
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 562, height: 380),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        win.title = "日期详情"
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 关键：跟随系统外观（不要被自己设的 NSAppearance 锁住）
        win.appearance = nil

        win.contentView = NSHostingView(rootView: DateDetailView(
            date: date,
            onClose: { [weak win] in win?.orderOut(nil) }
        ))

        // 定位：屏幕中央偏右
        win.center()
        win.setFrameOrigin(NSPoint(x: win.frame.origin.x + 80, y: win.frame.origin.y))
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.detailWindow = win
    }

    // MARK: - 全局点击监视（点别处关设置窗口）

    private func installGlobalMonitor(for win: NSWindow) {
        if let old = globalMonitor {
            NSEvent.removeMonitor(old)
            globalMonitor = nil
        }
        // delay 0.1 秒再装，让当前这次点击不立刻触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak win] in
            guard let self = self, let win = win else { return }
            self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                // 如果点击发生在窗口外，关掉
                if let win = self.settingsWindow, win.isVisible {
                    let mouseInWin = win.frame.contains(event.locationInWindow)
                    if !mouseInWin {
                        win.orderOut(nil)
                        if let m = self.globalMonitor {
                            NSEvent.removeMonitor(m)
                            self.globalMonitor = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - 点击行为

    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        // 左键 = 切换 popover
        togglePopover()
    }

    private func togglePopover() {
        if calendarPopover.isShown {
            calendarPopover.performClose(nil)
        } else if let button = statusItem.button {
            calendarPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            calendarPopover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openCal = NSMenuItem(title: "打开月历", action: #selector(openCalendar), keyEquivalent: "")
        openCal.target = self
        menu.addItem(openCal)

        let openSet = NSMenuItem(title: "设置...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        openSet.target = self
        menu.addItem(openSet)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 小历", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 小历", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openCalendar() {
        togglePopover()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "小历"
        alert.informativeText = "v1.0\n\n一个高度可定制的 macOS 菜单栏日历。\n农历 · 节日 · 节气 · 多日历源。\n\n左键菜单栏：月历\n月历左下：设置"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func appearanceDidChange() { refreshStatusItem(force: true) }
    @objc private func settingsDidChange() { refreshStatusItem(force: true) }
}

// MARK: - 菜单栏图标
enum StatusBarIcon {
    static func makeImage(day: Int = Calendar.current.component(.day, from: Date())) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = true
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: 16, height: 16)
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        path.lineWidth = 1.4
        NSColor.black.setStroke()
        path.stroke()

        let topBar = NSBezierPath()
        topBar.move(to: NSPoint(x: 4, y: 14.5))
        topBar.line(to: NSPoint(x: 14, y: 14.5))
        topBar.lineWidth = 1.2
        topBar.stroke()

        let dayString = String(day)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attrString = NSAttributedString(string: dayString, attributes: attrs)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 1,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)

        image.unlockFocus()
        return image
    }
}
