import SwiftUI
import AppKit
import EventKit

// MARK: - 日期详情面板
//
// 配色策略：完全跟随系统（系统浅色 → 浅色，系统暗色 → 暗色）
// 不用任何用户自定义的颜色，避免对比度对不上
//
struct DateDetailView: View {
    let date: Date
    let onClose: () -> Void

    @StateObject private var eventStore = EventStoreManager.shared
    @State private var events: [EKEvent] = []
    @State private var showNewEventSheet: Bool = false
    @State private var newEventTitle: String = ""
    @State private var newEventAllDay: Bool = true

    private var info: DayInfo { DayInfoBuilder.build(for: date) }
    private var greg: Calendar { Calendar(identifier: .gregorian) }

    /// 系统色：背景/分隔线等"环境色"用 NSColor
    private var bgColor: Color { Color(nsColor: .windowBackgroundColor) }
    private var panelBg: Color { Color(nsColor: .controlBackgroundColor) }
    private var dividerColor: Color { Color(nsColor: .separatorColor) }

    var body: some View {
        HStack(spacing: 0) {
            infoCard
                .frame(width: 280)
                .background(bgColor)
            Divider().background(dividerColor)
            eventsPanel
                .frame(width: 280)
                .background(bgColor)
        }
        .frame(width: 562, height: 380)
        .onAppear { refresh() }
    }

    // MARK: - 左侧信息卡
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部关闭按钮
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .padding(.trailing, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 大字日期 + 农历
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(info.solarMonth)月\(info.solarDay)日")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(weekdayString(info.solarWeekday))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let l = info.lunar {
                            HStack(spacing: 6) {
                                Text("\(l.ganzhiYear)年【\(l.zodiac)】")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(l.displayText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // 节气 / 节日
                        if info.hasAnyHoliday {
                            Text(info.holidaySummary)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)

                    // 信息条目
                    VStack(alignment: .leading, spacing: 0) {
                        if let l = info.lunar {
                            infoRow("年", value: "\(l.ganzhiYear)年 (\(l.zodiac)年)")
                            infoRow("月", value: "\(l.ganzhiMonth)月")
                            infoRow("日", value: "\(l.ganzhiDay)日")
                            infoRow("纳音", value: l.naYin)
                            infoRow("季节", value: l.season)
                        }
                        infoRow("周", value: "第\(greg.component(.weekOfYear, from: date))周")
                        if let term = info.solarTerm {
                            infoRow("节气", value: term, highlight: true)
                        }
                        if let h = info.solarHoliday {
                            infoRow("阳历节日", value: h, highlight: true)
                        }
                        if let h = info.lunarHoliday {
                            infoRow("农历节日", value: h, highlight: true)
                        }

                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                            .padding(.vertical, 8)

                        // 黄历字段（待补数据）
                        groupTitle("黄历")
                        placeholderRow("宜")
                        placeholderRow("忌")
                        placeholderRow("冲煞")
                        placeholderRow("五行")
                        placeholderRow("胎神")
                        placeholderRow("财位")
                        placeholderRow("星宿")
                        Text("宜忌等数据需配合查表，后续接入")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func infoRow(_ key: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: highlight ? .semibold : .regular))
                .foregroundStyle(highlight ? Color.accentColor : .primary)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func placeholderRow(_ key: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text("--")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func groupTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }

    // MARK: - 右侧事件面板
    private var eventsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("事件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    Task { await ensureAuthAndShowNew() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("新建事件")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // 授权状态
            if !eventStore.isGranted {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(eventStore.canRequestViaSystem
                         ? "需要日历访问权限"
                         : "日历访问权限被拒绝")
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                    Text(eventStore.canRequestViaSystem
                         ? "点击下方按钮授予访问日历的权限"
                         : "请在「系统设置 → 隐私与安全性 → 日历」中开启")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    if eventStore.canRequestViaSystem {
                        Button("授权") {
                            Task {
                                _ = await eventStore.requestAccess()
                                refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("打开系统设置") {
                            eventStore.openSystemPrivacySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("这一天没有事件")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events, id: \.eventIdentifier) { event in
                            eventRow(event)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .sheet(isPresented: $showNewEventSheet) {
            newEventSheet()
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(nsColor: event.calendar?.color ?? .systemBlue))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "(无标题)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if event.isAllDay {
                    Text("全天")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else if let s = event.startDate, let e = event.endDate {
                    Text("\(timeString(s)) - \(timeString(e))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(panelBg)
        )
    }

    private func newEventSheet() -> some View {
        VStack(spacing: 12) {
            Text("新建事件")
                .font(.system(size: 13, weight: .semibold))
            TextField("事件标题", text: $newEventTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            Toggle("全天", isOn: $newEventAllDay)
                .toggleStyle(.checkbox)
                .frame(width: 280, alignment: .leading)
            HStack {
                Button("取消") {
                    showNewEventSheet = false
                    newEventTitle = ""
                }
                Spacer()
                Button("保存") {
                    let trimmed = newEventTitle.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        _ = try? eventStore.createEvent(
                            title: trimmed,
                            date: date,
                            isAllDay: newEventAllDay
                        )
                        showNewEventSheet = false
                        newEventTitle = ""
                        refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(width: 280)
        }
        .padding(20)
        .frame(width: 360, height: 200)
    }

    // MARK: - 辅助

    private func refresh() {
        events = eventStore.events(for: date)
    }

    private func ensureAuthAndShowNew() async {
        if eventStore.isGranted {
            showNewEventSheet = true
            return
        }
        if eventStore.canRequestViaSystem {
            _ = await eventStore.requestAccess()
            if eventStore.isGranted {
                showNewEventSheet = true
            }
        } else {
            eventStore.openSystemPrivacySettings()
        }
    }

    private func weekdayString(_ wd: Int) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[wd - 1]
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
