import Foundation
import EventKit

// MARK: - 事件管理
//
// 用 EventKit 读 / 写 macOS 系统日历
// 第一次用会弹系统授权框
//
final class EventStoreManager: ObservableObject {
    static let shared = EventStoreManager()
    private let store = EKEventStore()

    @Published var authStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// 申请日历访问权限
    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { cont in
                store.requestFullAccessToEvents { granted, error in
                    DispatchQueue.main.async {
                        self.authStatus = granted ? .fullAccess : .denied
                    }
                    cont.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    DispatchQueue.main.async {
                        self.authStatus = granted ? .authorized : .denied
                    }
                    cont.resume(returning: granted)
                }
            }
        }
    }

    /// 获取某一天的所有事件
    func events(for date: Date) -> [EKEvent] {
        guard authStatus == .fullAccess || authStatus == .authorized else {
            return []
        }
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month, .day], from: date)),
              let end = cal.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { a, b in
            if a.isAllDay != b.isAllDay { return !a.isAllDay }
            return (a.startDate ?? .distantPast) < (b.startDate ?? .distantPast)
        }
    }

    /// 新建事件
    func createEvent(title: String, date: Date, isAllDay: Bool, durationMinutes: Int = 60) throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.isAllDay = isAllDay
        if isAllDay {
            event.startDate = Calendar.current.startOfDay(for: date)
            event.endDate = event.startDate
        } else {
            event.startDate = date
            event.endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: date)!
        }
        // 用第一个可用日历
        let available = store.calendars(for: .event)
        event.calendar = store.defaultCalendarForNewEvents ?? available.first
        try store.save(event, span: .thisEvent)
        return event
    }
}
