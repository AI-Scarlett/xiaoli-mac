import Foundation

// MARK: - 日期信息汇总
//
// 把"某一天"所有要展示的信息打包：
//   - 阳历月日
//   - 农历月日（精简显示）
//   - 干支年、生肖
//   - 当日节日（阳历 + 农历 + 节气 + 第几个星期几）
//   - 是否今天
//
struct DayInfo {
    let date: Date
    let isToday: Bool
    let solarMonth: Int
    let solarDay: Int
    let solarWeekday: Int   // 1=周日 ... 7=周六
    let lunar: LunarInfo?
    let solarHoliday: String?
    let lunarHoliday: String?
    let solarTerm: String?
    let weekdayHoliday: String?

    /// 节日摘要（多个会用「、」拼接）
    var holidaySummary: String {
        var parts: [String] = []
        if let h = solarTerm { parts.append(h) }
        if let h = solarHoliday { parts.append(h) }
        if let h = lunarHoliday { parts.append(h) }
        if let h = weekdayHoliday { parts.append(h) }
        return parts.joined(separator: " · ")
    }

    var hasAnyHoliday: Bool {
        solarHoliday != nil || lunarHoliday != nil
            || solarTerm != nil || weekdayHoliday != nil
    }
}

enum DayInfoBuilder {

    private static let gregorian = Calendar(identifier: .gregorian)
    private static let chinese = Calendar(identifier: .chinese)

    static func build(for date: Date) -> DayInfo {
        let comps = gregorian.dateComponents([.year, .month, .day, .weekday], from: date)
        let isToday = gregorian.isDateInToday(date)

        // 农历
        let lunar = LunarCalendar.lunarInfo(for: date)

        // 阳历节日
        let solarKey = String(format: "%02d-%02d", comps.month ?? 0, comps.day ?? 0)
        let solarHoliday = Holidays.solarFixed[solarKey]

        // 农历节日
        var lunarHoliday: String? = nil
        if let l = lunar {
            let lKey = String(format: "%02d-%02d", l.month, l.day)
            lunarHoliday = Holidays.lunarFixed[lKey]
        }

        // 节气
        let solarTerm = SolarTerms.termName(on: date)

        // "第几个星期几"型节日
        let weekdayHoliday = computeWeekdayHoliday(date: date)

        return DayInfo(
            date: date,
            isToday: isToday,
            solarMonth: comps.month ?? 0,
            solarDay: comps.day ?? 0,
            solarWeekday: comps.weekday ?? 1,
            lunar: lunar,
            solarHoliday: solarHoliday,
            lunarHoliday: lunarHoliday,
            solarTerm: solarTerm,
            weekdayHoliday: weekdayHoliday
        )
    }

    /// 计算"几月第几个星期几"型节日
    private static func computeWeekdayHoliday(date: Date) -> String? {
        let comps = gregorian.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let month = comps.month,
              let weekday = comps.weekday,
              let day = comps.day else { return nil }

        for rule in Holidays.nthWeekday where rule.0 == month && rule.1 == weekday {
            // 计算本月第几个该星期几
            guard let monthStart = gregorian.date(from: DateComponents(year: comps.year, month: month, day: 1))
            else { continue }
            let firstWeekday = gregorian.component(.weekday, from: monthStart)
            // 距本月第一个"目标 weekday"差几天
            let offset = (weekday - firstWeekday + 7) % 7
            let firstOccurrenceDay = 1 + offset
            let occurrence = (day - firstOccurrenceDay) / 7 + 1
            if occurrence == rule.2 {
                return rule.3
            }
        }
        return nil
    }
}
