import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 小历（XiaoLi）
//
// macOS 菜单栏日历小工具
// - 菜单栏：可配置显示图标/公历/农历/星期/时间/自定义
// - 左键菜单栏：弹出主面板（4 tab：通用/事件/样式/状态栏）
// - 右键菜单栏：常用菜单（打开面板/关于/退出）
// - 设置持久化到 UserDefaults
// - 通过 SMAppService 注册为登录项
//
@main
struct XiaoliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
