import Foundation

enum Speaker: String, Codable { case other, me }
enum Delivery: String, Codable { case confirmed, inserted, uncertain }
struct ChatEntry: Codable, Identifiable {
    var id = UUID()
    var role: Speaker
    var content: String
    var date = Date()
    var delivery: Delivery = .confirmed
}
struct ChatSession: Codable, Identifiable {
    var id = UUID()
    var name = "默认会话"
    var entries: [ChatEntry] = []
    var pinned = ""
}
struct ChatDatabase: Codable {
    var activeID: UUID
    var sessions: [ChatSession]
    init() {
        let session = ChatSession()
        activeID = session.id
        sessions = [session]
    }
}
final class ConversationStore {
    static let shared = ConversationStore()
    private let key = "jev.keyboard.chat.v2"
    private let group = "group.com.jev.keyboard2"
    private let lock = NSRecursiveLock()
    private var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    private init() {}
    private func read() -> ChatDatabase {
        guard let data = defaults.data(forKey: key),
              let result = try? JSONDecoder().decode(ChatDatabase.self, from: data) else { return .init() }
        return result
    }
    private func write(_ db: ChatDatabase) {
        guard let bytes = try? JSONEncoder().encode(db) else { return }
        defaults.set(bytes, forKey: key)
    }
    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    func activeSession() -> ChatSession {
        lock.lock(); defer { lock.unlock() }
        let db = read()
        return db.sessions.first(where: { $0.id == db.activeID }) ?? ChatSession()
    }
    @discardableResult
    func add(_ role: Speaker, _ text: String, delivery: Delivery = .confirmed) -> ChatEntry? {
        lock.lock(); defer { lock.unlock() }
        var db = read()
        guard let i = db.sessions.firstIndex(where: { $0.id == db.activeID }) else { return nil }
        let content = String(normalize(text).prefix(2000))
        guard !content.isEmpty else { return nil }
        let now = Date()
        db.sessions[i].entries.removeAll { now.timeIntervalSince($0.date) > 7 * 86400 }
        if let existing = db.sessions[i].entries.suffix(8).first(where: {
            $0.role == role && normalize($0.content) == content &&
            now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 1800
        }) { return existing }
        let entry = ChatEntry(role: role, content: content, date: now, delivery: delivery)
        db.sessions[i].entries.append(entry)
        db.sessions[i].entries = Array(db.sessions[i].entries.suffix(16))
        write(db)
        return entry
    }
    func sessions() -> [ChatSession] {
        lock.lock(); defer { lock.unlock() }
        return read().sessions
    }
    func newSession() {
        lock.lock(); defer { lock.unlock() }
        var db = read()
        let session = ChatSession(name: "会话 \(db.sessions.count + 1)")
        db.sessions.append(session)
        db.activeID = session.id
        write(db)
    }
    func selectSession(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var db = read()
        guard db.sessions.contains(where: { $0.id == id }) else { return }
        db.activeID = id
        write(db)
    }
    func clearActive() {
        lock.lock(); defer { lock.unlock() }
        var db = read()
        if let i = db.sessions.firstIndex(where: { $0.id == db.activeID }) {
            db.sessions[i].entries.removeAll()
        }
        write(db)
    }
    func setPinned(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        var db = read()
        if let i = db.sessions.firstIndex(where: { $0.id == db.activeID }) {
            db.sessions[i].pinned = String(text.prefix(1000))
        }
        write(db)
    }
}
