import Foundation
enum JevLanguage { case chinese, english }
enum JevStore { static let appGroupID = "goutou.test.group" }
@main
struct Smoke {
    static func main() throws {
        let source = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let rules = GoutouSkillFusion.extract(source)
        precondition(rules.contains("先接住情绪") && rules.contains("事实"))
        precondition(!rules.contains("仅返回 JSON 对象"))
        let suite = "jev.test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let st = JevContextStore(defaults: defaults)
        st.append(.them, text: "今天有点忙")
        st.append(.them, text: "今天有点忙")
        precondition(st.turns().count == 1, "clipboard duplicate")
        let context = st.contextString(forAnswering: "明天找你", language: .chinese)
        precondition(context.contains("今天有点忙"), "stored context not loaded")
        st.recordExchange(incoming: "明天找你", reply: "好啊，那你先忙")
        precondition(st.turns().count == 3)
        precondition(st.contextString(forAnswering: "行", language: .chinese).contains("未确认发送"))
        defaults.removePersistentDomain(forName:suite)
        print("SKILL_AND_CONTEXT_TEST_PASS: 666 reasoning extracted and persisted context included")
    }
}