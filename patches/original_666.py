from pathlib import Path
root=Path("original")
p=root/"Shared/JevPrompts.swift"
s=p.read_text(encoding="utf-8")
needle="动笔前先想清楚：对方此刻是什么情绪、真实意图是什么、上面的关系原则与方法哪一条适用；想清楚后再动笔，把方法化进回复里。"
assert s.count(needle)==1
s=s.replace(needle,"""动笔前先在心里区分：聊天已经证明了什么、只是假设什么、还不知道什么。结合最近的双方消息判断交流节奏、主动程度、具体行为和边界，不能凭一句话脑补爱意、冷淡、试探或吃醋。先选本轮唯一动作：正常接话 / 轻松调侃 / 具体澄清 / 体面后撤 / 适度推进，不要同时做一堆事。
你正在帮一个真人发微信，不是写关系咨询报告。候选回复不能暴露分析过程，必须适合用户直接复制发送。短消息可只回几个字，对方认真时才认真，不要求每条都给情绪价值或推进关系。""",1)
needle="- 不要照抄或提及上面的背景资料，只让它指导你的回复"
assert s.count(needle)==1
s=s.replace(needle,needle+"""
- 禁止客服腔和 AI 套话：「我理解你的感受」「听起来你」「谢谢你的分享」「我会一直在」「你舒服最重要」「好的呢」「确实如此」；除非上下文真的需要，否则不要道歉、承诺、讨好。
- 不要在每条最后强行加一个问题；不要每条都完整工整、加句号、带表情、附加解释。用户复制出去就是一条真实的人类消息。
- 注意之前我方候选可能只是插入输入框、未确认送达，不能推断对方读过。
- 两条回复应真正不同：第一条朴素自然，第二条按照上下文适度俏皮或更直接；不能只换几个同义词。""",1)
p.write_text(s,encoding="utf-8")

p=root/"Shared/JevContext.swift"
s=p.read_text(encoding="utf-8")
assert "var maxTurns: Int = 24" in s
s=s.replace("var maxTurns: Int = 24","var maxTurns: Int = 16",1)
needle="        t.append(ChatTurn(speaker: speaker, text: text))\n        _persist(t)"
assert s.count(needle)==1
s=s.replace(needle,"""        let now = Date()
        if !t.suffix(8).contains(where: {
            $0.speaker == speaker && $0.text == text &&
            now.timeIntervalSince($0.at) >= 0 && now.timeIntervalSince($0.at) < 1800
        }) {
            t.append(ChatTurn(speaker: speaker, text: text))
        }
        _persist(t)""",1)
# Previously candidate insertion was represented as a sent message. Mark as unconfirmed in context.
needle="t.append(ChatTurn(speaker: .me, text: reply))"
assert s.count(needle)==1
s=s.replace(needle,'t.append(ChatTurn(speaker: .me, text: "[点击插入，未确认发送] " + reply))',1)
# If previously recorded incoming message was far back in history, don't discard repeat forever.
needle="let already = t.contains { $0.speaker == .them && $0.text == incoming }"
assert s.count(needle)==1
s=s.replace(needle,"""let now = Date()
            let already = t.suffix(8).contains {
                $0.speaker == .them && $0.text == incoming &&
                now.timeIntervalSince($0.at) >= 0 && now.timeIntervalSince($0.at) < 1800
            }""",1)
p.write_text(s,encoding="utf-8")
print("ORIGINAL_JEV_FUSION_PATCH_APPLIED")
