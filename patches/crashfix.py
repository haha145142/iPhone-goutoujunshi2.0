#!/usr/bin/env python3
from pathlib import Path
root=Path("original")
ui=root/"Keyboard/Sources/KeyboardViewController.swift"
brain=root/"Shared/GoutouBrain.swift"
client=root/"Shared/GoutouBrainClient.swift"

def swap(p,old,new):
 s=p.read_text(encoding="utf-8")
 count=s.count(old)
 if count!=1: raise RuntimeError(f"Unexpected upstream code {p}: {count} matches for {old[:65]}")
 p.write_text(s.replace(old,new,1),encoding="utf-8")

(root/"Keyboard/Sources/GoutouStableMemory.swift").write_text(r'''import Foundation
enum GoutouStableMemory {
    private struct Entry: Codable {
        var role: String
        var text: String
        var date: Date
    }
    private static let storeKey = "goutou.v2.history.safe"
    private static let stageKey = "goutou.v2.crash.stage"
    private static let defaults = UserDefaults.standard
    static func stage(_ value: String) { defaults.set(value, forKey: stageKey) }
    static func previousStage() -> String? { defaults.string(forKey: stageKey) }
    static func finished() { defaults.removeObject(forKey: stageKey) }
    private static func load() -> [Entry] {
        guard let data = defaults.data(forKey: storeKey),
              let saved = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        let now = Date()
        return Array(saved.filter {
            now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 604800
        }.suffix(16))
    }
    private static func save(_ entries: [Entry]) {
        if let data = try? JSONEncoder().encode(Array(entries.suffix(16))) {
            defaults.set(data, forKey: storeKey)
        }
    }
    private static func add(_ role: String, _ raw: String) {
        let value = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(900))
        guard !value.isEmpty else { return }
        var entries = load()
        let now = Date()
        if !entries.suffix(8).contains(where: {
            $0.role == role && $0.text == value &&
            now.timeIntervalSince($0.date) >= 0 &&
            now.timeIntervalSince($0.date) < 1800
        }) {
            entries.append(Entry(role: role, text: value, date: now))
        }
        save(entries)
    }
    static func selectedReply(_ text: String) {
        add("inserted", text)
    }
    static func contextualize(_ incoming: [GoutouSegment], record: Bool) -> [GoutouSegment] {
        let history = load().map { item -> GoutouSegment in
            GoutouSegment(
                speaker: item.role == "them" ? .opponent : .me,
                text: item.role == "them"
                    ? "（历史对方消息）" + item.text
                    : "（历史已插入但未确认发送）" + item.text
            )
        }
        if record {
            for item in incoming where item.speaker == .opponent { add("them", item.text) }
        }
        return history + incoming
    }
    static func clearHistory() { defaults.removeObject(forKey: storeKey) }
}
''',encoding="utf-8")

swap(ui,'                self.textDocumentProxy.insertText(candidate.text)',
'''                self.textDocumentProxy.insertText(candidate.text)
                GoutouStableMemory.selectedReply(candidate.text)''')
swap(ui,'''        let pb = UIPasteboard.general
        let raw: String = autoreleasepool {
            let s = pb.string ?? ""
            return String(s.prefix(CLIPBOARD_MAX_CHARS)).trimmingCharacters(in: .whitespacesAndNewlines)
        }''',
'''        GoutouStableMemory.stage("1 读取剪贴板")
        let pb = UIPasteboard.general
        let raw: String = autoreleasepool {
            let s = pb.string ?? ""
            return String(s.prefix(1500)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        GoutouStableMemory.stage("2 已读取剪贴板")''')
swap(ui,'            if pb.hasImages {',
'''            GoutouStableMemory.finished()
            if pb.hasImages {''')
swap(ui,'''        let segments = GoutouSegmentBuilder.segments(from: raw)
        let displayMessage = segments.last?.text ?? raw
        run(segments: segments, displayMessage: displayMessage)''',
'''        GoutouStableMemory.stage("3 拆分消息")
        let segments = GoutouSegmentBuilder.segments(from: raw)
        let displayMessage = segments.last?.text ?? raw
        run(segments: segments, displayMessage: displayMessage)''')
swap(ui,'''        lastSegments = segments
        lastMessage = displayMessage
        setMode(.loading)''',
'''        lastSegments = segments
        lastMessage = displayMessage
        GoutouStableMemory.stage("4 切换分析界面")
        setMode(.loading)''')
swap(ui,'''        let cfg = JevStore.mergedConfigForKeyboard()
        let skill = loadSkillText()''',
'''        GoutouStableMemory.stage("5 读取AI设置")
        let cfg = JevStore.mergedConfigForKeyboard()
        let skill = loadSkillText()''')
swap(ui,'''            self.errorText = L("军师人格没打进包，需要重新构建一次。", "Strategist persona missing from the bundle; rebuild needed.")''',
'''            GoutouStableMemory.finished()
            self.errorText = L("军师人格没打进包，需要重新构建一次。", "Strategist persona missing from the bundle; rebuild needed.")''')
swap(ui,'''        GoutouBrainClient.analyze(config: cfg, skill: skill, segments: segments) { [weak self] result in''',
'''        GoutouStableMemory.stage("6 整理记忆")
        let contextual = GoutouStableMemory.contextualize(segments, record: lastSource == .clipboard)
        GoutouStableMemory.stage("7 等待AI响应")
        GoutouBrainClient.analyze(config: cfg, skill: skill, segments: contextual) { [weak self] result in''')
swap(ui,'''                switch result {
                case .success(let value):''',
'''                GoutouStableMemory.stage("8 展示分析结果")
                switch result {
                case .success(let value):''')
swap(ui,'''                        self.setMode(.result)
                    }
                case .failure(let error):''',
'''                        self.setMode(.result)
                        GoutouStableMemory.finished()
                    }
                case .failure(let error):''')
swap(ui,'''                    self.errorText = error.localizedDescription
                    self.setMode(.error)''',
'''                    self.errorText = error.localizedDescription
                    self.setMode(.error)
                    GoutouStableMemory.finished()''')
# If extension was killed, the next appearance shows which stage was reached.
swap(ui,'''        statusLabel.text = hasFullAccess ? L("Jev · 已连接", "Jev · Connected")
            : L("Jev · 需要完全访问", "Jev · Full Access required")''',
'''        statusLabel.text = GoutouStableMemory.previousStage().map { "上次中断：" + $0 }
            ?? (hasFullAccess ? L("Jev · 已连接", "Jev · Connected")
                : L("Jev · 需要完全访问", "Jev · Full Access required"))''')
swap(brain,"static let minReplies = 4","static let minReplies = 3")
swap(brain,"static let maxReplies = 5","static let maxReplies = 3")
swap(brain,"几条稳稳接住、几条稍微推进、几条直接问清楚",
     "第一条平常自然、第二条看语境略有趣、第三条温暖但不施压")
swap(brain,"不要把候选压到 2～3 条。","始终给恰好三条，不要机械同义改写。")
swap(brain,'''            Self.realismRules,''','''            Self.realismRules,
            "补充要求：像真人发微信，不要套话、咨询师口吻和每句反问。先看事实再作不确定推断，严禁脑补爱情或编造承诺。",''')
swap(client,"static let maxTokens = 8192","static let maxTokens = 3600")
# The v2 IPA contains a KnowledgeLibrary of browsable practical guides.
# The v2 source has the material in Resources/, but accidentally left it out
# of its App target. Include this only in the host App, NOT the memory-limited keyboard.
project=root/"project.yml"
meta=project.read_text(encoding="utf-8")
needle='''      - path: App/Assets.xcassets
      - path: Shared'''
if meta.count(needle)!=1: raise RuntimeError("project App sources changed")
meta=meta.replace(needle, '''      - path: App/Assets.xcassets
      - path: Shared
      - path: KnowledgeLibrary
        type: folder''', 1)
project.write_text(meta,encoding="utf-8")
print("CRASHFIX_PATCH_OK: Jev v2 source, keyboard crash breadcrumb, app-only resource fix")
