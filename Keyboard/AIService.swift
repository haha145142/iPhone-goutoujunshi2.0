import Foundation
struct AIResult {
    let analysis: String
    let state: String
    let replies: [String]
}
enum ChatError: LocalizedError {
    case missingKey, badEndpoint, failed(String), format
    var errorDescription: String? {
        switch self {
        case .missingKey: return "请先在键盘设置中填写 API Key"
        case .badEndpoint: return "API 地址无效，必须以 HTTPS 开头"
        case .failed(let detail): return "接口失败：\(detail)"
        case .format: return "模型返回格式错误，请重新分析"
        }
    }
}
enum AIService {
    static func analyze(prompt: String) async throws -> AIResult {
        let d = UserDefaults.standard
        let key = d.string(forKey: "apiKey") ?? ""
        guard !key.isEmpty else {throw ChatError.missingKey}
        let endpoint = d.string(forKey: "endpoint") ?? "https://api.deepseek.com/chat/completions"
        guard let url = URL(string: endpoint), url.scheme == "https" else {throw ChatError.badEndpoint}
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.timeoutInterval = 35
        r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": d.string(forKey: "model") ?? "deepseek-chat",
            "temperature": 0.7,
            "messages": [["role":"user","content":prompt]]
        ])
        let (data, response) = try await URLSession.shared.data(for: r)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ChatError.failed(String(data: data.prefix(200), encoding: .utf8) ?? "HTTP 错误")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any]
        let choices = obj?["choices"] as? [[String:Any]]
        let message = choices?.first?["message"] as? [String:Any]
        guard let raw = message?["content"] as? String else {throw ChatError.format}
        guard let a = raw.range(of: "【聊天分析】"),
              let b = raw.range(of: "【对方状态】"),
              let c = raw.range(of: "【推荐回复】"),
              a.upperBound <= b.lowerBound, b.upperBound <= c.lowerBound else {throw ChatError.format}
        let analysis = String(raw[a.upperBound..<b.lowerBound]).trimmingCharacters(in:.whitespacesAndNewlines)
        let state = String(raw[b.upperBound..<c.lowerBound]).trimmingCharacters(in:.whitespacesAndNewlines)
        let replies = raw[c.upperBound...].split(separator:"\n").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter {!$0.isEmpty}
        guard !analysis.isEmpty, analysis.count <= 50, !state.isEmpty, replies.count == 3 else {throw ChatError.format}
        return AIResult(analysis:analysis,state:state,replies:replies)
    }
}
