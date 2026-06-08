import SwiftUI
import AppKit

// MARK: - 主面板（4 tab）
//
// 通用 / 事件 / 样式 / 状态栏
// 顶部 tab 切换 + 底部"还原默认设置"按钮
//
struct MainPanelView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: Tab = .general
    let onClose: () -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case general = "通用"
        case events = "事件"
        case style = "样式"
        case statusbar = "状态栏"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "switch.2"
            case .events: return "calendar.badge.clock"
            case .style: return "paintpalette"
            case .statusbar: return "rectangle.topthird.inset.filled"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：标题栏 + tab 切换
            VStack(spacing: 8) {
                HStack {
                    Text("小历")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                HStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18))
                                Text(tab.rawValue)
                                    .font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == tab
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.clear)
                            )
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(settings.color(r: settings.panelBgR, g: settings.panelBgG, b: settings.panelBgB))

            Divider()

            // 内容区
            Group {
                switch selectedTab {
                case .general: GeneralTabView(settings: settings)
                case .events: EventsTabView(settings: settings)
                case .style: StyleTabView(settings: settings)
                case .statusbar: StatusBarTabView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("全部还原默认") {
                    // 重置为默认值
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .padding(10)
        }
        .frame(width: settings.panelWidth, height: settings.panelHeight)
        .background(settings.color(r: settings.panelBgR, g: settings.panelBgG, b: settings.panelBgB))
    }
}

// MARK: - 通用 Tab
struct GeneralTabView: View {
    @ObservedObject var settings: AppSettings
    @State private var loginItemStatus: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .onChange(of: settings.launchAtLogin) { _, newValue in
                                setLaunchAtLogin(newValue)
                            }
                        Text("开机后打开小历")
                    }
                }

                settingRow {
                    HStack {
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(true)
                        Text("快捷键")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("", text: $settings.globalShortcut)
                                .frame(width: 120)
                                .textFieldStyle(.roundedBorder)
                            Button("✕") {
                                settings.globalShortcut = ""
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.panelAnimation)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text("面板动画")
                        Spacer()
                        Text(settings.panelAnimation ? "启用" : "关闭")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                }

                Divider().padding(.vertical, 4)

                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.showCalendarDots)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text("日历事件")
                        Spacer()
                        Text("显示小圆点")
                            .foregroundStyle(.secondary)
                    }
                }

                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.showHolidayBadge)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text("法定节假日")
                        Spacer()
                        Text("显示角标")
                            .foregroundStyle(.secondary)
                    }
                }

                settingRow {
                    HStack {
                        Text("一周开始于")
                        Spacer()
                        Picker("", selection: $settings.weekStartsOn) {
                            Text("周日").tag(1)
                            Text("周一").tag(2)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                    }
                }

                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.holidayReminder)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text("提醒通知")
                        Spacer()
                        Text("节假日推送")
                            .foregroundStyle(.secondary)
                    }
                }

                settingRow {
                    HStack {
                        Toggle("", isOn: $settings.showLunar)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text("农历信息")
                        Spacer()
                        Text(settings.showLunar ? "显示" : "隐藏")
                            .foregroundStyle(.secondary)
                    }
                }

                if !loginItemStatus.isEmpty {
                    Text(loginItemStatus)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try LoginItem.register()
                loginItemStatus = "已注册为登录项"
            } else {
                try LoginItem.unregister()
                loginItemStatus = "已取消登录项"
            }
        } catch {
            loginItemStatus = "失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - 事件 Tab
struct EventsTabView: View {
    @ObservedObject var settings: AppSettings
    @State private var newName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("勾选在面板中展示的事件类型")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            List {
                ForEach(settings.subscribedCalendars, id: \.self) { name in
                    HStack {
                        Toggle(name, isOn: .constant(true))
                            .toggleStyle(.checkbox)
                        Spacer()
                        Button("删除") {
                            var arr = settings.subscribedCalendars
                            arr.removeAll { $0 == name }
                            settings.subscribedCalendars = arr
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    }
                }
            }
            .listStyle(.plain)

            Divider()

            HStack {
                TextField("新建日历名", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("新建") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        var arr = settings.subscribedCalendars
                        arr.append(trimmed)
                        settings.subscribedCalendars = arr
                        newName = ""
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - 样式 Tab
struct StyleTabView: View {
    @ObservedObject var settings: AppSettings

    private let colorFields: [(label: String, rKey: ReferenceWritableKeyPath<AppSettings, Double>, gKey: ReferenceWritableKeyPath<AppSettings, Double>, bKey: ReferenceWritableKeyPath<AppSettings, Double>)] = [
        ("面板背景", \.panelBgR, \.panelBgG, \.panelBgB),
        ("标题颜色", \.titleR, \.titleG, \.titleB),
        ("一般日期", \.normalDayR, \.normalDayG, \.normalDayB),
        ("周末日期", \.weekendR, \.weekendG, \.weekendB),
        ("节日日期", \.holidayR, \.holidayG, \.holidayB),
        ("当前日期", \.todayR, \.todayG, \.todayB),
        ("日历事件", \.eventR, \.eventG, \.eventB),
        ("加班日期", \.workdayR, \.workdayG, \.workdayB),
        ("休假日期", \.dayOffR, \.dayOffG, \.dayOffB)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: Binding(
                    get: { settings.darkTheme ? 1 : 0 },
                    set: { settings.darkTheme = $0 == 1 }
                )) {
                    Text("状态栏").tag(0)
                    Text("通知中心").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                // 颜色
                LazyVGrid(columns: [
                    GridItem(.flexible(), alignment: .trailing),
                    GridItem(.flexible(), alignment: .leading)
                ], spacing: 10) {
                    ForEach(colorFields, id: \.label) { field in
                        colorRow(field: field)
                    }
                }

                Divider().padding(.vertical, 4)

                // 暗色主题开关
                HStack {
                    Toggle("对面板使用暗色主题", isOn: $settings.darkTheme)
                        .toggleStyle(.checkbox)
                    Spacer()
                }

                Divider().padding(.vertical, 4)

                // 滑块
                sliderRow("面板宽度", value: $settings.panelWidth, range: 280...480, suffix: "pt")
                sliderRow("面板高度", value: $settings.panelHeight, range: 320...600, suffix: "pt")
                sliderRow("元素大小", value: $settings.elementSize, range: 10...20, suffix: "pt")
            }
            .padding(16)
        }
    }

    private func colorRow(field: (label: String, rKey: ReferenceWritableKeyPath<AppSettings, Double>, gKey: ReferenceWritableKeyPath<AppSettings, Double>, bKey: ReferenceWritableKeyPath<AppSettings, Double>)) -> some View {
        HStack {
            Text(field.label)
                .font(.system(size: 12))
                .frame(width: 70, alignment: .trailing)
            ColorWellBinding(
                r: Binding(get: { settings[keyPath: field.rKey] }, set: { settings[keyPath: field.rKey] = $0 }),
                g: Binding(get: { settings[keyPath: field.gKey] }, set: { settings[keyPath: field.gKey] = $0 }),
                b: Binding(get: { settings[keyPath: field.bKey] }, set: { settings[keyPath: field.bKey] = $0 })
            )
            .frame(width: 50, height: 24)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 70, alignment: .trailing)
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue))\(suffix)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
        }
    }
}

// 颜色选择器（用 NSColorWell 包一层）
struct ColorWellBinding: NSViewRepresentable {
    @Binding var r: Double
    @Binding var g: Double
    @Binding var b: Double

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        well.color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        let cur = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        if nsView.color != cur {
            nsView.color = cur
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: ColorWellBinding
        init(_ parent: ColorWellBinding) { self.parent = parent }

        @objc func changed(_ sender: NSColorWell) {
            parent.r = Double(sender.color.redComponent)
            parent.g = Double(sender.color.greenComponent)
            parent.b = Double(sender.color.blueComponent)
        }
    }
}

// MARK: - 状态栏 Tab
struct StatusBarTabView: View {
    @ObservedObject var settings: AppSettings
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("设置各模块，可拖拽进行排序")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("显示秒", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            List {
                ForEach(settings.modules) { cfg in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { cfg.enabled },
                            set: { newVal in
                                var arr = settings.modules
                                if let idx = arr.firstIndex(where: { $0.id == cfg.id }) {
                                    arr[idx].enabled = newVal
                                    settings.modules = arr
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        Text(cfg.module.displayName)
                        Spacer()
                        if cfg.module == .solar {
                            Picker("", selection: $settings.solarFormat) {
                                Text("11月29日").tag("11月29日")
                                Text("11/29").tag("11/29")
                                Text("29日").tag("29日")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        } else if cfg.module == .lunar {
                            Picker("", selection: $settings.lunarFormat) {
                                Text("初五").tag("初五")
                                Text("五月廿三").tag("五月廿三")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        } else if cfg.module == .time {
                            Picker("", selection: Binding(
                                get: { settings.timeFormat24h ? 1 : 0 },
                                set: { settings.timeFormat24h = $0 == 1 }
                            )) {
                                Text("24 小时制").tag(1)
                                Text("12 小时制").tag(0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        } else if cfg.module == .custom {
                            TextField("yyyy-MM-dd", text: $settings.customFormat)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                }
                .onMove { from, to in
                    var arr = settings.modules
                    arr.move(fromOffsets: from, toOffset: to)
                    settings.modules = arr
                }
            }
            .listStyle(.plain)
            // macOS 上拖拽排序直接靠 List 自带的 onMove 支持
            // 鼠标悬停右侧会自动出现拖拽手柄

            Spacer()
            Text("macOS 10.12 以上按住 ⌘ 键可拖动状态栏图标")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }
}
