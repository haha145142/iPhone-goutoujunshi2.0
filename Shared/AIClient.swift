import Foundation

struct Analysis: Codable {
    let analysis: String
    let state: String
    let replies: [String]
}
enum AIError: LocalizedError {
    case missingKey, badResponse, invalidOutput
    var errorDescription: String? {
        switch self {
        case .missingKey: return "请先在主 App 中配置 API Key"
        case .badResponse: return "AI 请求失败，请检查接口和网络"
        case .invalidOutput: return "AI 回复格式不正确，请重试"
        }
    }
}
struct AIClient {
    private let defaults = UserDefaults(suiteName: "group.com.jev.keyboard2") ?? .standard
    func analyze(_ prompt: String) async throws -> Analysis {
        let key = defaults.string(forKey: "apiKey") ?? ""
        guard !key.isEmpty else { throw AIError.missingKey }
        let endpoint = defaults.string(forKey: "apiEndpoint") ?? "https://api.deepseek.com/chat/completions"
        guard let url = URL(string: endpoint), url.scheme == "https" else { throw AIError.badResponse }
        let model = defaults.string(forKey: "model") ?? "deepseek-chat"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "temperature": 0.7,
            "messages": [["role": "user", "content": prompt]]
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIError.badResponse }
        let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let raw = completion.choices.first?.message.content else { throw AIError.badResponse }
        return try AnalysisParser.parse(raw)
    }
}
private struct ChatCompletion: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
enum AnalysisParser {
    static func parse(_ raw: String) throws -> Analysis {
        guard let a = raw.range(of: "【聊天分析】"),
              let s = raw.range(of: "【对方状态】"),
              let r = raw.range(of: "【推荐回复】"),
              a.upperBound <= s.lowerBound, s.upperBound <= r.lowerBound else {
            throw AIError.invalidOutput
        }
        let analysis = String(raw[a.upperBound..<s.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let state = String(raw[s.upperBound..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let replies = raw[r.upperBound...]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !analysis.isEmpty, analysis.count <= 50, !state.isEmpty, replies.count == 3 else {
            throw AIError.invalidOutput
        }
        return Analysis(analysis: analysis, state: state, replies: replies)
    }
}
