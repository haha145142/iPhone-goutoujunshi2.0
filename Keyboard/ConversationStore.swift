import Foundation

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    var role: String
    var text: String
    var sent: Bool
    var time = Date()
}
struct Session: Codable, Identifiable {
    var id = UUID()
    var name: String = "默认会话"
    var messages: [ChatMessage] = []
    var pinned = ""
}
struct MemoryDB: Codable {
    var active: UUID
    var sessions: [Session]
    init() { let s = Session(); active = s.id; sessions = [s] }
}
final class ConversationStore {
    static let shared = ConversationStore()
    private let defaults = UserDefaults.standard
    private let key = "goutou.mem.v2"
    private init() {}
    private func read() -> MemoryDB {
        guard let data = defaults.data(forKey: key), let db = try? JSONDecoder().decode(MemoryDB.self, from: data) else { return MemoryDB() }
        return db
    }
    private func save(_ db: MemoryDB) {
        if let data = try? JSONEncoder().encode(db) { defaults.set(data, forKey: key) }
    }
    func active() -> Session {
        let db = read()
        return db.sessions.first(where: { $0.id == db.active }) ?? db.sessions[0]
    }
    func sessions() -> [Session] { read().sessions }
    func create() {
        var db = read()
        let s = Session(name: "会话 \(db.sessions.count + 1)")
        db.sessions.append(s); db.active = s.id; save(db)
    }
    func select(_ id: UUID) {
        var db = read()
        if db.sessions.contains(where: {$0.id == id}) { db.active = id; save(db) }
    }
    func clear() {
        var db = read()
        guard let i = db.sessions.firstIndex(where: {$0.id == db.active}) else {return}
        db.sessions[i].messages = []; save(db)
    }
    func remember(_ value: String) {
        var db = read()
        guard let i = db.sessions.firstIndex(where: {$0.id == db.active}) else {return}
        db.sessions[i].pinned = String(value.prefix(1000)); save(db)
    }
    @discardableResult func add(_ role: String, _ raw: String, sent: Bool = true) -> ChatMessage? {
        var db = read()
        guard let i = db.sessions.firstIndex(where: {$0.id == db.active}) else {return nil}
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !text.isEmpty else {return nil}
        let now = Date()
        db.sessions[i].messages.removeAll {now.timeIntervalSince($0.time) > 7*86400}
        if let existing = db.sessions[i].messages.suffix(8).first(where: {
            $0.role == role && $0.text == text && now.timeIntervalSince($0.time) < 1800
        }) { return existing }
        let item = ChatMessage(role: role, text: text, sent: sent, time: now)
        db.sessions[i].messages.append(item)
        db.sessions[i].messages = Array(db.sessions[i].messages.suffix(16))
        save(db); return item
    }
}
