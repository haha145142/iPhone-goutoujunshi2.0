import UIKit

final class KeyboardViewController: UIInputViewController {
    private let store = ConversationStore.shared
    private let stack = UIStackView()
    private let detail = UILabel()
    private let analyzeButton = UIButton(type: .system)
    private var activeTask: Task<Void,Never>?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo:view.topAnchor,constant:8),
            stack.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:12),
            stack.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:view.bottomAnchor,constant:-8)
        ])
        let head = UIButton(type:.system)
        head.setTitle("狗头军师 · \(store.active().name) ▾",for:.normal)
        head.addAction(UIAction { [weak self] _ in self?.showSessions(head) },for:.touchUpInside)
        stack.addArrangedSubview(head)
        analyzeButton.setTitle("✨ 分析剪贴板",for:.normal)
        analyzeButton.titleLabel?.font = .boldSystemFont(ofSize:19)
        analyzeButton.addTarget(self,action:#selector(analyze),for:.touchUpInside)
        stack.addArrangedSubview(analyzeButton)
        detail.numberOfLines = 0
        detail.font = .systemFont(ofSize:13)
        detail.text = "复制消息 → 分析 → 点击回复"
        stack.addArrangedSubview(detail)
        let settings = UIButton(type:.system)
        settings.setTitle("⚙ 设置 API Key / 记为我 / 清空",for:.normal)
        settings.addTarget(self,action:#selector(showSettings),for:.touchUpInside)
        stack.addArrangedSubview(settings)
        let next = UIButton(type:.system)
        next.setTitle("🌐 切换键盘",for:.normal)
        next.addTarget(self,action:#selector(advanceToNextInputMode),for:.touchUpInside)
        stack.addArrangedSubview(next)
    }
    private func showSessions(_ sender: UIView) {
        let alert = UIAlertController(title:"切换对话",message:"不同联系人请切换会话，避免串线",preferredStyle:.actionSheet)
        for s in store.sessions() {
            alert.addAction(UIAlertAction(title:s.name,style:.default,handler:{[weak self] _ in
                self?.store.select(s.id)
                self?.detail.text = "当前会话：\(s.name)"
            }))
        }
        alert.addAction(UIAlertAction(title:"新建会话",style:.default,handler:{[weak self] _ in
            self?.store.create(); self?.detail.text = "已创建空白会话"
        }))
        alert.addAction(UIAlertAction(title:"取消",style:.cancel))
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds
        present(alert,animated:true)
    }
    @objc private func showSettings() {
        let alert = UIAlertController(title:"狗头军师设置",message:"API 配置存于键盘扩展本地，不上传 GitHub",preferredStyle:.alert)
        alert.addTextField { $0.placeholder = "DeepSeek API Key"; $0.isSecureTextEntry = true; $0.text = UserDefaults.standard.string(forKey:"apiKey") }
        alert.addTextField { $0.placeholder = "HTTPS API 地址"; $0.text = UserDefaults.standard.string(forKey:"endpoint") ?? "https://api.deepseek.com/chat/completions" }
        alert.addTextField { $0.placeholder = "模型"; $0.text = UserDefaults.standard.string(forKey:"model") ?? "deepseek-chat" }
        alert.addAction(UIAlertAction(title:"保存",style:.default,handler:{ a in
            let fields = alert.textFields ?? []
            if fields.count == 3 {
                UserDefaults.standard.set(fields[0].text ?? "",forKey:"apiKey")
                UserDefaults.standard.set(fields[1].text ?? "",forKey:"endpoint")
                UserDefaults.standard.set(fields[2].text ?? "",forKey:"model")
            }
        }))
        alert.addAction(UIAlertAction(title:"记为我刚发的消息",style:.default,handler:{[weak self] _ in
            if let text = UIPasteboard.general.string { _ = self?.store.add("me",text) }
        }))
        alert.addAction(UIAlertAction(title:"清空当前记忆",style:.destructive,handler:{[weak self] _ in self?.store.clear() }))
        alert.addAction(UIAlertAction(title:"取消",style:.cancel))
        present(alert,animated:true)
    }
    @objc private func analyze() {
        guard activeTask == nil else {return}
        guard hasFullAccess else { detail.text = "请启用「允许完全访问」"; return }
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in:.whitespacesAndNewlines),
              !clipboard.isEmpty else {detail.text = "剪贴板没有文字";return}
        guard let message = store.add("other",clipboard) else {return}
        let session = store.active()
        let prompt = GoutouPrompt.make(session,latest:message)
        analyzeButton.isEnabled = false
        detail.text = "正在分析…"
        activeTask = Task { [weak self] in
            guard let self else {return}
            defer {self.activeTask = nil;self.analyzeButton.isEnabled = true}
            do {
                let result = try await AIService.analyze(prompt:prompt)
                guard self.store.active().id == session.id else {return}
                self.render(result)
            } catch {self.detail.text = error.localizedDescription}
        }
    }
    private func render(_ result: AIResult) {
        for v in stack.arrangedSubviews where v.accessibilityIdentifier == "reply" {
            stack.removeArrangedSubview(v);v.removeFromSuperview()
        }
        detail.text = "【聊天分析】\n\(result.analysis)\n【对方状态】\n\(result.state)"
        for reply in result.replies {
            let b = UIButton(type:.system)
            b.accessibilityIdentifier = "reply"
            b.titleLabel?.numberOfLines = 0
            b.contentHorizontalAlignment = .left
            b.setTitle("➜ "+reply,for:.normal)
            b.addAction(UIAction { [weak self] _ in
                guard let self else {return}
                self.textDocumentProxy.insertText(reply)
                _ = self.store.add("me",reply,sent:false)
            },for:.touchUpInside)
            stack.addArrangedSubview(b)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        activeTask?.cancel()
    }
}
