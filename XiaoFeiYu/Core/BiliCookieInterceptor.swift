import Foundation

/// 给 bilibili.com 请求自动注入 SESSDATA（用户号优先，内置号兜底）。
final class BiliCookieInterceptor: URLProtocol {
    private var task: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host?.lowercased(), host.contains("bilibili.com") else {
            return false
        }
        return request.value(forHTTPHeaderField: "Cookie") == nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var request = self.request
        let sess = BiliSession.shared.effectiveSessdata
        if !sess.isEmpty {
            request.setValue("SESSDATA=\(sess)", forHTTPHeaderField: "Cookie")
        }

        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task?.resume()
    }

    override func stopLoading() {
        task?.cancel()
    }
}
