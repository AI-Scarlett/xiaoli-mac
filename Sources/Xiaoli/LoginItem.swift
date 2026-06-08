import Foundation

// MARK: - 登录项管理
//
// 优先用 SMAppService（macOS 13+），如果不可用就降级到 LaunchAgent plist
// 这套方式在所有 macOS 版本上都能用
//
enum LoginItem {

    static let bundleId = "cn.com.mavis.MiniCal"
    static let label = "cn.com.mavis.MiniCal"

    /// 读取当前状态
    static func isEnabled() -> Bool {
        // 优先用 SMAppService
        if let cls = NSClassFromString("SMAppService") as? NSObject.Type {
            let resp = cls.perform(NSSelectorFromString("mainApp"))
            if let svc = resp?.takeUnretainedValue() as? NSObject {
                if let s = svc.perform(NSSelectorFromString("status"))?.takeUnretainedValue(),
                   let statusInt = s as? Int {
                    // SMAppService.Status: notRegistered=0, enabled=1, requiresApproval=2, notFound=3
                    return statusInt == 1
                }
            }
        }
        // 降级：看 LaunchAgent plist 是否存在
        return FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func register() throws {
        // 优先 SMAppService
        if let cls = NSClassFromString("SMAppService") as? NSObject.Type {
            let resp = cls.perform(NSSelectorFromString("mainApp"))
            if let svc = resp?.takeUnretainedValue() as? NSObject {
                _ = svc.perform(NSSelectorFromString("register"))
                return
            }
        }
        // 降级：写 LaunchAgent
        try writeLaunchAgent()
    }

    static func unregister() throws {
        if let cls = NSClassFromString("SMAppService") as? NSObject.Type {
            let resp = cls.perform(NSSelectorFromString("mainApp"))
            if let svc = resp?.takeUnretainedValue() as? NSObject {
                _ = svc.perform(NSSelectorFromString("unregister"))
                return
            }
        }
        try removeLaunchAgent()
    }

    // MARK: - LaunchAgent 后备方案

    private static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    private static func writeLaunchAgent() throws {
        let appPath = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [appPath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL)
        // 让 launchd 立即加载
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["bootstrap", "gui/\(getuid())", plistURL.path]
        try? task.run()
        task.waitUntilExit()
    }

    private static func removeLaunchAgent() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            // 先 unload
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["bootout", "gui/\(getuid())", plistURL.path]
            try? task.run()
            task.waitUntilExit()
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
