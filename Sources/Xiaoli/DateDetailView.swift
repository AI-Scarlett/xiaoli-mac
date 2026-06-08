import SwiftUI
import AppKit
import EventKit

// MARK: - 日期详情面板
//
// 左侧：日期信息卡(农历、干支、节气、节日...) 
// 右侧：事件列表 + 新建按钮
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

    var body: some View {
        HStack(spacing: 0) {
            infoCard
                .frame(width: 280)
            Divider()
            eventsPanel
                .frame(width: 280)
        }
        .frame(width: 562, height: 380)
        .background(settings.color(r: settings.panelBgR, g: settings.panelBgG, b: settings.panelBgB))
        .onAppear {
            // 第一次进详情窗：主动请求权限(如果还没授权) 
            Task {
                if eventStore.authStatus == .notDetermined {
                    _ = await eventStore.requestAccess()
                }
                refresh()
            }
        }
    }

    // 局部 settings(用静态值) 
    private var settings: AppSettings { AppSettings() }

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
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(info.solarMonth)月\(info.solarDay)日")
                                .font(.system(size: 22, weight: .bold))
                            Text(weekdayString(info.solarWeekday))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let l = info.lunar {
                            HStack(spacing: 6) {
                                Text("\(l.ganzhiYear)年【\(l.zodiac)】")
                                    .font(.system(size: 12, weight: .medium))
                                Text(l.displayText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // 节气 / 节日
                        if info.hasAnyHoliday {
                            Text(info.holidaySummary)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    Divider().background(Color.white.opacity(0.1))

                    // 信息条目
                    VStack(alignment: .leading, spacing: 0) {
                        if let l = info.lunar {
                            infoRow("年", value: "\(l.ganzhiYear)年(\(l.zodiac) 年) ")
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

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 8)

                        // 黄历字段(待补数据) 
                        groupTitle("黄历")
                        placeholderRow("宜")
                        placeholderRow("忌")
                        placeholderRow("冲煞")
                        placeholderRow("五行")
                        placeholderRow("胎神")
                        placeholderRow("财位")
                        placeholderRow("星宿")
                        Text("(宜忌等数据需配合查表，后续接入) ")
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
            if eventStore.authStatus != .fullAccess && eventStore.authStatus != .authorized {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(eventStore.authStatus == .notDetermined
                         ? "准备请求日历访问权限..."
                         : "需要日历访问权限")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                    if eventStore.authStatus != .notDetermined {
                        Button("授权") {
                            Task {
                                _ = await eventStore.requestAccess()
                                refresh()
                            }
                        }
                        .buttonStyle(.bordered)
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
            // 颜色点
            Circle()
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1)) ?? .blue)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "(无标题) ")
                    .font(.system(size: 12, weight: .medium))
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
                .fill(Color.white.opacity(0.05))
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
        if eventStore.authStatus != .fullAccess && eventStore.authStatus != .authorized {
            _ = await eventStore.requestAccess()
        }
        if eventStore.authStatus == .fullAccess || eventStore.authStatus == .authorized {
            showNewEventSheet = true
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
