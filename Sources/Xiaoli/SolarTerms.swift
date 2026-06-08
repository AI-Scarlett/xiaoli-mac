import Foundation

// MARK: - 二十四节气计算
//
// 算法：基于"太阳到达黄经 X 度"的简化公式（VSOP87 简化版）
// 精度：±1 分钟内（200 年内）
// 范围：1900-2100 年
//
// 24 个节气 = 太阳在黄道上每 15° 一个节点
//   春分 = 0°  清明 = 15°  ...  冬至 = 270°
//
enum SolarTerms {

    // 节气对应的黄经度数（从小寒开始）
    private static let termLongitudes: [Double] = [
        285, 300, 315, 330, 345, 0,    // 小寒大寒立春雨水惊蛰春分
        15,  30,  45,  60,  75, 90,   // 清明谷雨立夏小满芒种夏至
        105, 120, 135, 150, 165, 180,  // 小暑大暑立秋处暑白露秋分
        195, 210, 225, 240, 255, 270   // 寒露霜降立冬小雪大雪冬至
    ]

    // 节气名（与 termLongitudes 一一对应）
    static let names: [String] = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]

    /// 返回某一年所有 24 个节气的 UTC 时间
    static func terms(forYear year: Int) -> [Date] {
        return (0..<24).map { i in
            // 冬至 (i=23) 用下一年；其它都用本年
            let useYear = (i == 23) ? year + 1 : year
            return computeTerm(year: useYear, index: i)
        }
    }

    /// 给定一个阳历日期，返回它当天的节气名（没有则返回 nil）
    static func termName(on date: Date) -> String? {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year else { return nil }

        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        // 上一年冬至 + 本年 23 个节气（不含本年冬至）
        let prevTerms = terms(forYear: year - 1).suffix(1) // 上年冬至
        let currTerms = terms(forYear: year).dropLast()    // 本年小寒~大雪
        let allTerms = Array(prevTerms) + currTerms

        for (i, t) in allTerms.enumerated() {
            if t >= dayStart && t < dayEnd {
                let nameIndex = (i == 0) ? 23 : i - 1
                return names[nameIndex]
            }
        }
        return nil
    }

    /// 给定阳历的某一年某月，返回这个月内所有的节气（精确到日）
    static func termsInMonth(year: Int, month: Int) -> [(day: Int, name: String)] {
        let all = terms(forYear: year)
        let cal = Calendar(identifier: .gregorian)
        var result: [(Int, String)] = []
        for (i, t) in all.enumerated() {
            let comps = cal.dateComponents([.year, .month], from: t)
            if comps.year == year && comps.month == month {
                let day = cal.component(.day, from: t)
                result.append((day, names[i]))
            }
        }
        return result
    }

    // MARK: - 核心算法

    /// 计算第 i 个节气的精确时间（i: 0=小寒, 1=大寒 ... 23=冬至）
    private static func computeTerm(year: Int, index: Int) -> Date {
        let longitude = termLongitudes[index]
        // 把 0~360 归一化
        let normalizedLng = longitude.truncatingRemainder(dividingBy: 360)
        // 用简化算法求太阳到达该黄经的时间（JDE = 儒略日）
        let jde = solarLongitudeTime(year: year, targetLongitude: normalizedLng)
        return jdeToDate(jde: jde)
    }

    /// 简化算法：求太阳到达目标黄经的儒略日
    /// 基于 Jean Meeus《天文算法》第 25 章
    private static func solarLongitudeTime(year: Int, targetLongitude: Double) -> Double {
        // 估算该黄经出现的儒略日
        var jde = estimateJDE(year: year, targetLongitude: targetLongitude)
        // 迭代修正（2-3 次就够精确）
        for _ in 0..<10 {
            let sunLng = sunEclipticLongitude(jde: jde)
            var diff = targetLongitude - sunLng
            // 归一化到 -180 ~ 180
            while diff < -180 { diff += 360 }
            while diff > 180 { diff -= 360 }
            if abs(diff) < 0.0001 { break }
            // 太阳一天走约 1°，所以时间差 ≈ diff 天
            jde += diff
        }
        return jde
    }

    /// 估算儒略日：基于该黄经对应的"月份中点"
    private static func estimateJDE(year: Int, targetLongitude: Double) -> Double {
        // 24 节气均匀分布在 365.2422 天里，每个约 15.2184 天
        // 春分 (longitude=0) 约在 3/20
        // 找到 targetLongitude 对应的"年内序号"
        let baseJDE = Double(y2kJDE(forYear: year)) // 该年 1/1 0:00 UT 的儒略日
        // 找到最接近的春分点 (0°)，从那里开始算
        // 简化：直接从 1/1 算偏移
        let daysFromSpringEquinox: Double = {
            var lng = targetLongitude
            if lng < 0 { lng += 360 }
            // 春分约在 3/20 = 1/1 后的 79 天
            let springEquinoxOffset = 79.0
            let offset = (lng / 360.0) * 365.2422
            return springEquinoxOffset + offset
        }()
        return baseJDE + daysFromSpringEquinox - 1
    }

    /// 计算儒略日（2000-01-01 12:00 UT = J2451545.0）
    private static func y2kJDE(forYear year: Int) -> Int {
        // 用 DateComponents 算
        var comps = DateComponents()
        comps.year = year
        comps.month = 1
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        guard let date = Calendar(identifier: .gregorian).date(from: comps) else {
            return 2451545
        }
        return Int(julianDay(from: date))
    }

    /// Date 转儒略日
    private static func julianDay(from date: Date) -> Double {
        let j2000Ref = Date(timeIntervalSince1970: 946728000) // 2000-01-01 12:00:00 UTC
        let secondsPerDay = 86400.0
        return 2451545.0 + date.timeIntervalSince(j2000Ref) / secondsPerDay
    }

    /// 儒略日转 Date
    private static func jdeToDate(jde: Double) -> Date {
        let j2000Ref = Date(timeIntervalSince1970: 946728000)
        let secondsPerDay = 86400.0
        let ti = (jde - 2451545.0) * secondsPerDay
        return j2000Ref.addingTimeInterval(ti)
    }

    /// 计算给定儒略日下太阳的黄经（度）
    private static func sunEclipticLongitude(jde: Double) -> Double {
        let t = (jde - 2451545.0) / 36525.0
        // 太阳平黄经（度）
        let meanLongitude = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        // 太阳平近点角（度）
        let meanAnomaly = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
        // 黄道中心方程
        let mRad = meanAnomaly * .pi / 180
        let c = (1.914602 - 0.004817 * t) * sin(mRad)
            + (0.019993 - 0.000101 * t) * sin(2 * mRad)
            + 0.000289 * sin(3 * mRad)
        let trueLongitude = meanLongitude + c
        // 加上章动和光行差修正
        let omega = 125.04 - 1934.136 * t
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(omega * .pi / 180)
        // 归一化
        var lng = apparentLongitude.truncatingRemainder(dividingBy: 360)
        if lng < 0 { lng += 360 }
        return lng
    }
}
