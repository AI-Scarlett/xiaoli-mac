import Foundation
import SwiftUI

// MARK: - 全局配置
//
// 用 @AppStorage 持久化到 UserDefaults
// 颜色用 RGBA 4 个 Double 存（0~1），方便 Color 重建
//
final class AppSettings: ObservableObject {

    // 通用
    @AppStorage("general.launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("general.globalShortcut") var globalShortcut: String = "^⌘X"   // 仅显示用
    @AppStorage("general.panelAnimation") var panelAnimation: Bool = false
    @AppStorage("general.showCalendarDots") var showCalendarDots: Bool = true
    @AppStorage("general.showHolidayBadge") var showHolidayBadge: Bool = true
    @AppStorage("general.weekStartsOn") var weekStartsOn: Int = 2   // 1=周日 2=周一
    @AppStorage("general.holidayReminder") var holidayReminder: Bool = true
    @AppStorage("general.showLunar") var showLunar: Bool = true

    // 样式 - 颜色
    @AppStorage("style.panelBgR") var panelBgR: Double = 0.12
    @AppStorage("style.panelBgG") var panelBgG: Double = 0.12
    @AppStorage("style.panelBgB") var panelBgB: Double = 0.13
    @AppStorage("style.panelBgA") var panelBgA: Double = 1.0

    @AppStorage("style.titleR") var titleR: Double = 0.78
    @AppStorage("style.titleG") var titleG: Double = 0.78
    @AppStorage("style.titleB") var titleB: Double = 0.78

    @AppStorage("style.normalDayR") var normalDayR: Double = 1.0
    @AppStorage("style.normalDayG") var normalDayG: Double = 1.0
    @AppStorage("style.normalDayB") var normalDayB: Double = 1.0

    @AppStorage("style.weekendR") var weekendR: Double = 1.0
    @AppStorage("style.weekendG") var weekendG: Double = 1.0
    @AppStorage("style.weekendB") var weekendB: Double = 1.0

    @AppStorage("style.holidayR") var holidayR: Double = 0.40
    @AppStorage("style.holidayG") var holidayG: Double = 0.65
    @AppStorage("style.holidayB") var holidayB: Double = 0.85

    @AppStorage("style.todayR") var todayR: Double = 0.93
    @AppStorage("style.todayG") var todayG: Double = 0.30
    @AppStorage("style.todayB") var todayB: Double = 0.30

    @AppStorage("style.eventR") var eventR: Double = 0.62
    @AppStorage("style.eventG") var eventG: Double = 0.45
    @AppStorage("style.eventB") var eventB: Double = 0.85

    @AppStorage("style.workdayR") var workdayR: Double = 0.95
    @AppStorage("style.workdayG") var workdayG: Double = 0.60
    @AppStorage("style.workdayB") var workdayB: Double = 0.45

    @AppStorage("style.dayOffR") var dayOffR: Double = 0.40
    @AppStorage("style.dayOffG") var dayOffG: Double = 0.80
    @AppStorage("style.dayOffB") var dayOffB: Double = 0.90

    @AppStorage("style.darkTheme") var darkTheme: Bool = true

    // 样式 - 尺寸
    @AppStorage("style.panelWidth") var panelWidth: Double = 340
    @AppStorage("style.panelHeight") var panelHeight: Double = 440
    @AppStorage("style.elementSize") var elementSize: Double = 14

    // 状态栏模块（顺序 + 启停）
    // 用 JSON 字符串存
    @AppStorage("statusbar.modules") private var modulesData: String = ""

    // 状态栏格式
    @AppStorage("statusbar.solarFormat") var solarFormat: String = "11月29日"
    @AppStorage("statusbar.lunarFormat") var lunarFormat: String = "初五"
    @AppStorage("statusbar.timeFormat24h") var timeFormat24h: Bool = true
    @AppStorage("statusbar.customFormat") var customFormat: String = "yyyy-MM-dd"

    // 事件 - 已订阅的日历源名称
    @AppStorage("events.subscribed") private var subscribedData: String = "[\"日历\"]"

    enum StatusBarModule: String, CaseIterable, Identifiable, Codable {
        case icon, solar, lunar, weekday, time, custom
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .icon: return "图标"
            case .solar: return "公历"
            case .lunar: return "农历"
            case .weekday: return "星期"
            case .time: return "时间"
            case .custom: return "自定义"
            }
        }
    }

    struct ModuleConfig: Codable, Identifiable {
        var module: StatusBarModule
        var enabled: Bool
        var id: String { module.rawValue }
    }

    var modules: [ModuleConfig] {
        get {
            if let data = modulesData.data(using: .utf8),
               let arr = try? JSONDecoder().decode([ModuleConfig].self, from: data) {
                return arr
            }
            // 默认顺序
            return StatusBarModule.allCases.map { ModuleConfig(module: $0, enabled: $0 == .icon) }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let s = String(data: data, encoding: .utf8) {
                modulesData = s
            }
        }
    }

    var subscribedCalendars: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(subscribedData.utf8))) ?? ["日历"]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let s = String(data: data, encoding: .utf8) {
                subscribedData = s
            }
        }
    }

    // 颜色辅助
    func color(r: Double, g: Double, b: Double, a: Double = 1.0) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}
