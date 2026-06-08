import SwiftUI
import AppKit

// MARK: - 月历面板（仿小历紧凑样式）
//
// 顶部：< 2026 / 6 >
// 周表头：M T W T F S S
// 网格：阳历日（大）+ 农历/节日/节气（小）
// 状态条：⚙ 设置 | 当前日期 + 第N周 + 农历 | X 关闭
//
struct CalendarPanelView: View {
    @ObservedObject var settings: AppSettings
    @State private var displayedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var displayedMonth: Int = Calendar.current.component(.month, from: Date())

    let onOpenSettings: () -> Void
    let onOpenDetail: (Date) -> Void
    let onClose: () -> Void

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = settings.weekStartsOn
        return cal
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayRow
            monthGrid
            statusBar
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: 头部
    private var header: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Text("\(displayedYear) / \(displayedMonth)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }

    // MARK: 周表头（M T W T F S S）
    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 网格
    private var monthGrid: some View {
        let cells = makeMonthCells()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(cells, id: \.id) { cell in
                if let info = cell.info {
                    dayCell(info: info)
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
    }

    private func dayCell(info: DayInfo) -> some View {
        let isToday = info.isToday
        let weekend = (info.solarWeekday == 1 || info.solarWeekday == 7)
        let hasSolarTerm = info.solarTerm != nil
        let hasSolarHoliday = info.solarHoliday != nil
        let hasLunarHoliday = info.lunarHoliday != nil
        let hasAnyHoliday = hasSolarTerm || hasSolarHoliday || hasLunarHoliday

        let dayColor: Color = {
            if isToday { return .white }
            if weekend { return settings.color(r: settings.weekendR, g: settings.weekendG, b: settings.weekendB) }
            if hasAnyHoliday { return settings.color(r: settings.holidayR, g: settings.holidayG, b: settings.holidayB) }
            return settings.color(r: settings.normalDayR, g: settings.normalDayG, b: settings.normalDayB)
        }()

        let labelColor: Color = {
            if isToday { return .white.opacity(0.9) }
            if hasSolarTerm { return settings.color(r: settings.holidayR, g: settings.holidayG, b: settings.holidayB) }
            if hasAnyHoliday { return settings.color(r: settings.holidayR, g: settings.holidayG, b: settings.holidayB).opacity(0.9) }
            return .secondary
        }()

        return VStack(spacing: 0) {
            Text("\(info.solarDay)")
                .font(.system(size: 14, weight: isToday ? .bold : .semibold))
                .foregroundStyle(dayColor)
                .monospacedDigit()
            if settings.showLunar || hasAnyHoliday {
                Text(lunarLabel(info: info))
                    .font(.system(size: 9, weight: hasAnyHoliday ? .medium : .regular))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(
            Group {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .padding(2)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenDetail(info.date)
        }
        .help(info.holidaySummary)
    }

    // MARK: 状态条
    private var statusBar: some View {
        HStack(spacing: 6) {
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("设置")

            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)

            Text(currentStatusText())
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - 计算

    private func shiftMonth(_ delta: Int) {
        var m = displayedMonth + delta
        var y = displayedYear
        if m < 1 { m += 12; y -= 1 }
        else if m > 12 { m -= 12; y += 1 }
        displayedMonth = m
        displayedYear = y
    }

    private func lunarLabel(info: DayInfo) -> String {
        if let term = info.solarTerm { return term }
        if let h = info.solarHoliday { return h }
        if let h = info.lunarHoliday { return h }
        if let l = info.lunar {
            if l.day == 1 { return l.monthName }
            return l.dayName
        }
        return ""
    }

    /// 周表头 M T W T F S S（图里是英文单字母）
    private func orderedWeekdaySymbols() -> [String] {
        // 默认周一开头
        let start = calendar.firstWeekday - 1   // 0 for Monday
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        return Array(symbols[start..<symbols.count] + symbols[0..<start])
    }

    private struct DayCell {
        let id: Int
        let info: DayInfo?
    }

    private func makeMonthCells() -> [DayCell] {
        let cal = self.calendar
        guard let monthStart = cal.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: 1)),
              let monthRange = cal.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - cal.firstWeekday + 7) % 7

        var cells: [DayCell] = []
        var id = 0

        for _ in 0..<leadingBlanks {
            cells.append(DayCell(id: id, info: nil))
            id += 1
        }

        let greg = Calendar(identifier: .gregorian)
        for day in monthRange {
            if let date = greg.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: day)) {
                let info = DayInfoBuilder.build(for: date)
                cells.append(DayCell(id: id, info: info))
            }
            id += 1
        }

        // 补齐 6 行
        while cells.count < 42 {
            cells.append(DayCell(id: id, info: nil))
            id += 1
        }

        return cells
    }

    private func currentStatusText() -> String {
        let now = Date()
        let greg = Calendar(identifier: .gregorian)
        let lunar = LunarCalendar.lunarInfo(for: now)
        let month = greg.component(.month, from: now)
        let day = greg.component(.day, from: now)
        let weekOfYear = greg.component(.weekOfYear, from: now)
        let week = greg.component(.weekday, from: now)
        let weekdayChars = ["日", "一", "二", "三", "四", "五", "六"]
        let weekdayChar = weekdayChars[week - 1]

        let lunarText = lunar?.displayText ?? ""
        return "\(month)月\(day)日 第\(weekOfYear)周 \(weekdayChar) \(lunarText)"
    }
}
