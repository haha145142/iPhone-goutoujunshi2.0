#!/usr/bin/env python3
"""Minimal source fix for the unmodified Doubao ZIP, applied in CI after extraction."""
from pathlib import Path
import re
p = Path("JevJarvis-Ultimate/Keyboard/Sources/KeyboardViewController.swift")
src = p.read_text(encoding="utf-8")
duplicate = '''    /// 清空自动积累的上下文（对方消息 + 我发出的回复），下次分析不再携带。
    @objc private func clearContext() {
        JevContext.clear()
        render()
        flashFooter(L("已清空上下文", "Context cleared"), color: KB.secondaryText)
    }

'''
assert src.count("private func clearContext()") == 2, "Expected exactly two known clearContext() methods; inspect source manually"
assert src.count(duplicate) == 1, "Known duplicate clearContext() implementation missing; refusing blind patch"
out = src.replace(duplicate, "", 1)
assert out.count("private func clearContext()") == 1
p.write_text(out, encoding="utf-8")
print("SOURCE_FIX_OK: removed the extra clearContext() declaration; preserved original handler at ~693")
