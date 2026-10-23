import UIKit

final class KeyboardViewController: UIInputViewController {
    private let store = ConversationStore.shared
    private let panel = UIStackView()
    private let statusLabel = UILabel()
    private let analyzeButton = UIButton(type: .system)
    private var task: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        panel.axis = .vertical
        panel.spacing = 7
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 290)
        ])
        let header = UIButton(type: .system)
        header.setTitle("狗头军师 · 切换会话", for: .normal)
        header.addTarget(self, action: #selector(switchSession), for: .touchUpInside)
        panel.addArrangedSubview(header)
        analyzeButton.setTitle("✨ 分析剪贴板", for: .normal)
        analyzeButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        analyzeButton.addTarget(self, action: #selector(analyze), for: .touchUpInside)
        panel.addArrangedSubview(analyzeButton)
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.text = "复制对方消息 → 点击分析 → 选择回复"
        panel.addArrangedSubview(statusLabel)
        let manual = UIButton(type: .system)
        manual.setTitle("记为我刚发的消息（从剪贴板）", for: .normal)
        manual.addTarget(self, action: #selector(recordMine), for: .touchUpInside)
        panel.addArrangedSubview(manual)
        let globe = UIButton(type: .system)
        globe.setTitle("🌐 切换系统键盘", for: .normal)
        globe.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        panel.addArrangedSubview(globe)
    }

    @objc private func switchSession() {
        let sessions = store.sessions()
        let current = store.activeSession().id
        guard let i = sessions.firstIndex(where: { $0.id == current }) else { return }
        store.selectSession(sessions[(i + 1) % sessions.count].id)
        statusLabel.text = "当前：\(store.activeSession().name)"
    }
    @objc private func recordMine() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        _ = store.add(.me, text)
        statusLabel.text = "已记为我方消息"
    }
    @objc private func analyze() {
        guard task == nil else { return }
        guard hasFullAccess else {
            statusLabel.text = "请在系统键盘设置中启用允许完全访问"
            return
        }
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            statusLabel.text = "剪贴板没有文字"
            return
        }
        let sessionID = store.activeSession().id
        guard let entry = store.add(.other, text) else { return }
        let prompt = GoutouPrompt.make(ContextBuilder.build(session: store.activeSession(), latestID: entry.id))
        analyzeButton.isEnabled = false
        statusLabel.text = "分析中…"
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.analyzeButton.isEnabled = true
                self.task = nil
            }
            do {
                let result = try await AIClient().analyze(prompt)
                guard self.store.activeSession().id == sessionID else { return }
                self.show(result)
            } catch {
                self.statusLabel.text = "分析失败：\(error.localizedDescription)"
            }
        }
    }
    private func show(_ result: Analysis) {
        panel.arrangedSubviews.filter { $0.accessibilityIdentifier == "reply" }.forEach {
            panel.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        statusLabel.text = "【聊天分析】\n\(result.analysis)\n【对方状态】\n\(result.state)"
        for reply in result.replies {
            let button = UIButton(type: .system)
            button.accessibilityIdentifier = "reply"
            button.titleLabel?.numberOfLines = 2
            button.contentHorizontalAlignment = .left
            button.setTitle("➜ " + reply, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.textDocumentProxy.insertText(reply)
                _ = self.store.add(.me, reply, delivery: .inserted)
            }, for: .touchUpInside)
            panel.addArrangedSubview(button)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        task?.cancel()
    }
}
