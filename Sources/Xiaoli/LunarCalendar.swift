import Foundation

// MARK: - 农历信息（扩充版）
//
// 用系统的 Chinese Calendar 算农历日期，
// 干支年 + 生肖手算。
// 节气、节日另算。
//
struct LunarInfo {
    let day: Int
    let month: Int
    let isLeapMonth: Bool
    let ganzhiYear: String   // 干支年：丙午
    let zodiac: String       // 生肖：马
    let monthName: String    // 农历月名
    let dayName: String      // 农历日名
    let ganzhiDay: String    // 干支日
    let ganzhiMonth: String  // 干支月（按节气月算近似）
    let naYin: String        // 纳音五行
    let season: String       // 季节（春夏秋冬/长夏）

    var displayText: String {
        if isLeapMonth {
            return "闰\(monthName)\(dayName)"
        }
        return "\(monthName)\(dayName)"
    }
}

enum LunarCalendar {

    private static let monthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]

    private static let dayPrefix = ["初", "十", "廿", "卅"]
    private static let dayDigits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    private static let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    private static let elements = ["木", "火", "火", "土", "土", "金", "金", "水", "水", "木"]  // 纳音五行简表（按地支分，对应天干会变）

    /// 60 甲子对应的纳音五行（简化版：按地支查）
    /// 数据是查表：甲子乙丑海中金、丙寅丁卯炉中火、...
    /// 这里用一个 30 项循环的简化版本：每 2 个干支对应一个纳音
    private static let naYinTable: [String] = [
        "海中金", "海中金", "炉中火", "炉中火", "大林木", "大林木", "路旁土", "路旁土",
        "剑锋金", "剑锋金", "山头火", "山头火", "涧下水", "涧下水", "城头土", "城头土",
        "白蜡金", "白蜡金", "杨柳木", "杨柳木", "泉中水", "泉中水", "大海水", "大海水",
        "沙中金", "沙中金", "山下火", "山下火", "平地木", "平地木", "壁上土", "壁上土",
        "金箔金", "金箔金", "覆灯火", "覆灯火", "天河水", "天河水", "大驿土", "大驿土",
        "钗钏金", "钗钏金", "桑柘木", "桑柘木", "大溪水", "大溪水", "沙中土", "沙中土",
        "天上火", "天上火", "石榴木", "石榴木", "大海水", "大海水", "沙中土", "沙中土"
    ]

    static func lunarInfo(for date: Date) -> LunarInfo? {
        let cal = Calendar(identifier: .chinese)
        let comps = cal.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
        guard let month = comps.month,
              let day = comps.day else {
            return nil
        }

        let gregYear = gregorianYear(for: date)
        // 干支年：公元 4 年 = 甲子年（序号 0）
        let ganzhiIdx = ((gregYear - 4) % 60 + 60) % 60
        let stem = heavenlyStems[ganzhiIdx % 10]
        let branch = earthlyBranches[ganzhiIdx % 12]
        let zodiac = zodiacs[ganzhiIdx % 12]
        let naYin = naYinTable[ganzhiIdx]

        // 干支月：用农历月 + 节气月（简化：用 gregorianMonth 近似）
        // 干支月 = 寅月起算（农历正月 = 寅月）
        let gregMonth = Calendar(identifier: .gregorian).component(.month, from: date)
        let monthBranchIdx = ((gregMonth + 1) % 12) // 简化估算
        let monthStemIdx = (ganzhiIdx % 5) * 2 // 粗略
        let ganzhiMonth = "\(heavenlyStems[monthStemIdx % 10])\(earthlyBranches[monthBranchIdx])"

        // 干支日：用一个简单公式（公历日期对 60 取模 + 偏移基准）
        // 基准：1900-01-01 = 甲戌日（序号 10）
        let baseOrdinal = 10
        let greg = Calendar(identifier: .gregorian)
        let dayOrdinal = greg.ordinality(of: .day, in: .year, for: date) ?? 0
        let dayOfYear1900 = (gregYear - 1900) * 365 + (gregYear - 1900) / 4 + dayOrdinal
        let dayGanzhiIdx = ((baseOrdinal + dayOfYear1900) % 60 + 60) % 60
        let ganzhiDay = "\(heavenlyStems[dayGanzhiIdx % 10])\(earthlyBranches[dayGanzhiIdx % 12])"

        // 季节（按公历月）
        let season: String
        switch gregMonth {
        case 3, 4, 5: season = "春"
        case 6, 7, 8: season = "夏"
        case 9, 10, 11: season = "秋"
        default: season = "冬"
        }

        let isLeap = comps.isLeapMonth ?? false
        let monthName = monthNames[max(0, month - 1)]
        let dayName = dayNameFunc(day: day)

        return LunarInfo(
            day: day,
            month: month,
            isLeapMonth: isLeap,
            ganzhiYear: "\(stem)\(branch)",
            zodiac: zodiac,
            monthName: monthName,
            dayName: dayName,
            ganzhiDay: ganzhiDay,
            ganzhiMonth: ganzhiMonth,
            naYin: naYin,
            season: season
        )
    }

    private static func dayNameFunc(day: Int) -> String {
        switch day {
        case 1...9: return "初\(dayDigits[day])"
        case 10: return "初十"
        case 11...19: return "十\(dayDigits[day - 10])"
        case 20: return "二十"
        case 21...29: return "廿\(dayDigits[day - 20])"
        case 30: return "卅"
        default: return "\(day)"
        }
    }

    private static func gregorianYear(for date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.component(.year, from: date)
    }
}
