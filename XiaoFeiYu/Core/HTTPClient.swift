import Foundation

enum HTTPError: LocalizedError {
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "网络返回异常"
        case .badStatus(let code): return "网络错误 \(code)"
        }
    }
}

enum HTTPClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.protocolClasses = [BiliCookieInterceptor.self] + (config.protocolClasses ?? [])
        return URLSession(configuration: config)
    }()

    static let mobileUA =
        "Mozilla/5.0 (Linux; Android 13; 22081212C) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"

    static func data(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<400).contains(http.statusCode) else {
            throw HTTPError.badStatus(http.statusCode)
        }
        return (data, http)
    }

    static func json(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        let (data, _) = try await data(url, headers: headers)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return object
    }

    static func postJSON(
        _ url: URL,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw HTTPError.invalidResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HTTPError.invalidResponse
        }
        return object
    }

    static func text(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> (String, URL) {
        let (data, response) = try await data(url, headers: headers)
        let text = String(data: data, encoding: .utf8) ?? ""
        return (text, response.url ?? url)
    }

    /// 跟随 302，返回最终 URL
    static func finalURL(_ url: URL, headers: [String: String] = [:]) async throws -> URL {
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (_, response) = try await session.data(for: request)
        return response.url ?? url
    }
}
