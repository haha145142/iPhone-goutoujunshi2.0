import Foundation

@main
struct FusionSmoke {
    static func main() {
        let raw = "今天有点忙！明天再找你。"
        let incoming = GoutouSegmentBuilder.segments(from: raw)
        precondition(incoming.count == 2, "Punctuation segmentation failed")
        precondition(incoming.last?.text == "明天再找你。", "Latest message incorrect")
        let long = String(repeating: "好", count: 500)
        precondition(GoutouSegmentBuilder.segments(from: long)[0].text.count == 300, "Segment cap broken")

        GoutouStableMemory.clearHistory()
        let first = GoutouStableMemory.contextualize(incoming, record: true)
        precondition(first.count == incoming.count, "First-run history is not empty")
        GoutouStableMemory.selectedReply("行，那你先忙")
        let second = GoutouStableMemory.contextualize(
            GoutouSegmentBuilder.segments(from: "忙完找我就行"), record: true)
        precondition(second.count == 4, "History was not included")
        precondition(second.contains { $0.text.contains("未确认发送") }, "Unsent text not distinguished")
        let prompt = GoutouBrain.userMessage(segments: second)
        precondition(prompt.contains("忙完找我就行"), "Latest message absent from API body")
        precondition(prompt.contains("行，那你先忙"), "Saved chat history absent from API body")
        let rules = GoutouBrain.systemPrompt(skill: "测试人格")
        precondition(rules.contains("测试人格"), "Strategist skill missing")
        precondition(rules.contains("三条") || rules.contains("3 条"), "Reply count contract missing")
        GoutouStableMemory.clearHistory()
        GoutouStableMemory.finished()
        print("SMOKE_PASS: clipboard segmentation, stored context, recent reply, prompt assembly")
    }
}
