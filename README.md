# 小历 (XiaoLi)

> 一个高度可定制的 macOS 菜单栏日历工具。替代老旧的 tinycal。

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 截图

<!-- TODO: 补两张截图：菜单栏 + 月历面板 + 日期详情 -->

## 特性

- **菜单栏日历图标**：自动跟随系统深色 / 浅色外观
- **月历面板**：点击菜单栏弹出
  - 阳历 + **农历**（干支年/生肖/纳音/季节）
  - **24 节气**（天文算法精确计算）
  - **国内外节日**：阳历 + 农历 + 第几周第几天型
  - 翻月、翻年、点击日期进入详情
- **日期详情窗口**：
  - 农历信息卡（年/月/日干支、纳音、节气、节日）
  - 事件管理（基于 macOS EventKit，与系统日历 App 同步）
- **设置面板**（4 个 tab）：
  - 通用：开机启动、快捷键、周首日、农历显隐
  - 事件：日历源订阅
  - 样式：9 个颜色 + 3 个尺寸滑块 + 暗色主题
  - 状态栏：6 个模块勾选 + 24h/12h + 自定义格式
- **开机自启**：`~/Library/LaunchAgents` 方案（无需额外权限）

## 编译 & 运行

需要 macOS 14+ 和 Xcode 命令行工具（`xcode-select --install`）。

```bash
swift build -c release
.build/release/Xiaoli
```

## 打包为 .app

```bash
APP=/Applications/小历.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Xiaoli "$APP/Contents/MacOS/小历"
cp Scripts/Info.plist "$APP/Contents/"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
open "$APP"
```

## 开机自启

```bash
PLIST=~/Library/LaunchAgents/cn.com.mavis.MiniCal.plist
cp Scripts/cn.com.mavis.MiniCal.plist "$PLIST"
launchctl bootstrap gui/$(id -u) "$PLIST"
```

## 项目结构

```
Xiaoli/
├── Package.swift
├── README.md
├── LICENSE
├── .gitignore
├── Scripts/
│   ├── Info.plist
│   └── cn.com.mavis.MiniCal.plist
└── Sources/Xiaoli/
    ├── XiaoliApp.swift           # @main 入口
    ├── AppDelegate.swift         # 状态栏 + Popover + 窗口管理
    ├── AppSettings.swift         # 用户配置（@AppStorage 持久化）
    ├── CalendarPanelView.swift   # 月历面板（popover 内容）
    ├── DateDetailView.swift      # 日期详情窗口
    ├── MainPanelView.swift       # 设置面板（4 tab）
    ├── EventStoreManager.swift   # EventKit 封装
    ├── LoginItem.swift           # 登录项管理
    ├── DayInfo.swift             # 单日信息汇总
    ├── LunarCalendar.swift       # 农历（Chinese Calendar + 手算干支）
    ├── SolarTerms.swift          # 二十四节气天文算法
    └── Holidays.swift            # 节日字典
```

## 实现要点

- **菜单栏图标颜色**：用 `isTemplate = true`，系统自动反色
- **农历**：用 `Calendar(identifier: .chinese)` 拿月日，干支年用 `(公历年-4) mod 60`
- **节气**：Meeus《天文算法》简化版，迭代修正到 ±0.0001°
- **窗口分层**：
  - 月历：`NSPopover` (`.transient`)，点别处自动消失
  - 设置 / 详情：`NSWindow` + 全局鼠标监视
- **不占 Dock**：`NSApp.setActivationPolicy(.accessory)`
- **开机自启**：`~/Library/LaunchAgents` plist，免去特殊权限

## 路线图

- [ ] 黄历"宜/忌/财位/星宿"完整数据接入
- [ ] 事件编辑 / 删除
- [ ] 农历节日提前 N 天通知
- [ ] 多语言支持（英文 UI）
- [ ] 主屏小组件（WidgetKit）

## 贡献

欢迎 PR。提交前请：

1. `swift build -c release` 通过
2. 保持代码风格一致
3. 重要算法改动请附测试用例

## License

MIT
