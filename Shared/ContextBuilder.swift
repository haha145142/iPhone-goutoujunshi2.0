import Foundation

enum ContextBuilder {
    static func build(session: ChatSession, latestID: UUID) -> String {
        let history = session.entries.filter { $0.date >= Date().addingTimeInterval(-7 * 86400) }
        let latest = history.first(where: { $0.id == latestID })
        var lines: [String] = []
        if !session.pinned.isEmpty {
            lines += ["【主动记住的背景】", session.pinned]
        }
        lines.append("【最近对话】")
        for message in history where message.id != latestID {
            let label: String
            if message.role == .other { label = "对方" }
            else if message.delivery == .inserted { label = "我（已插入，未确认发送）" }
            else if message.delivery == .uncertain { label = "我（疑似发送）" }
            else { label = "我（已确认）" }
            lines.append("\(label)：\(message.content)")
        }
        lines += ["【对方最新消息】", latest?.content ?? ""]
        return lines.joined(separator: "\n")
    }
}
