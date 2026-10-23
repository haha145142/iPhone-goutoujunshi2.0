import SwiftUI
@main struct Goutou2App: App {
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 20) {
                Text("狗头军师 2.0").font(.largeTitle.bold())
                Text("复制对方消息 → 切换到狗头军师键盘 → 分析 → 点击回复")
                Text("启用方法").font(.headline)
                Text("设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 狗头军师键盘")
                Text("启用「允许完全访问」，再从键盘面板中设置 API Key。")
                Text("聊天缓存和 API Key 保存在键盘扩展自己的本地存储中，不使用 App Group。")
                Text("注意：需要在签名工具中分别正确签名主 App 与 Keyboard Extension。")
            }.padding()
        }
    }
}
