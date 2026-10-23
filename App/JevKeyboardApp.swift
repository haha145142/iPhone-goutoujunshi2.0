import SwiftUI

@main
struct JevKeyboardApp: App {
    var body: some Scene {
        WindowGroup { SettingsView() }
    }
}
struct SettingsView: View {
    @State private var key = ""
    @State private var endpoint = "https://api.deepseek.com/chat/completions"
    @State private var model = "deepseek-chat"
    @State private var pinned = ""
    private let defaults = UserDefaults(suiteName: "group.com.jev.keyboard2") ?? .standard
    var body: some View {
        NavigationStack {
            Form {
                Section("AI 服务") {
                    SecureField("DeepSeek / 兼容 API Key", text: $key)
                    TextField("接口地址", text: $endpoint).textInputAutocapitalization(.never)
                    TextField("模型", text: $model).textInputAutocapitalization(.never)
                    Button("保存设置") {
                        defaults.set(key, forKey: "apiKey")
                        defaults.set(endpoint, forKey: "apiEndpoint")
                        defaults.set(model, forKey: "model")
                        ConversationStore.shared.setPinned(pinned)
                    }
                }
                Section("当前会话记忆") {
                    TextEditor(text: $pinned).frame(height: 100)
                    Button("新建空白会话") {
                        ConversationStore.shared.newSession()
                        pinned = ""
                    }
                    Button("清空当前会话消息", role: .destructive) {
                        ConversationStore.shared.clearActive()
                    }
                    Text("只在点击分析时读取剪贴板；历史最多16条，7天后按需过期。")
                }
                Section("启用键盘") {
                    Text("设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 狗头军师；打开允许完全访问。")
                }
            }
            .navigationTitle("狗头军师")
            .onAppear {
                key = defaults.string(forKey: "apiKey") ?? ""
                endpoint = defaults.string(forKey: "apiEndpoint") ?? endpoint
                model = defaults.string(forKey: "model") ?? model
                pinned = ConversationStore.shared.activeSession().pinned
            }
        }
    }
}
