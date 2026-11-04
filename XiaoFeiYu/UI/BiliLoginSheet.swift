import SwiftUI
import WebKit

struct BiliLoginSheet: View {
    var onLogin: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BiliLoginWebView { sess in
                BiliSession.shared.saveUser(sess)
                onLogin(sess)
                dismiss()
            }
            .navigationTitle("登录 B站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct BiliLoginWebView: UIViewRepresentable {
    var onSESSDATA: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSESSDATA: onSESSDATA)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        config.websiteDataStore.httpCookieStore.add(context.coordinator)
        webView.load(URLRequest(url: URL(string: "https://passport.bilibili.com/login")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let onSESSDATA: (String) -> Void
        private var done = false

        init(onSESSDATA: @escaping (String) -> Void) {
            self.onSESSDATA = onSESSDATA
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(in: webView)
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { [weak self] cookies in
                self?.handle(cookies)
            }
        }

        private func checkCookies(in webView: WKWebView) {
            // SESSDATA 是 HttpOnly，document.cookie 读不到，必须走 WKHTTPCookieStore
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                self?.handle(cookies)
            }
        }

        private func handle(_ cookies: [HTTPCookie]) {
            guard !done else { return }
            guard let sess = cookies.first(where: {
                $0.name == "SESSDATA" && $0.domain.contains("bilibili") && $0.value.count >= 16
            })?.value else { return }

            done = true
            DispatchQueue.main.async {
                self.onSESSDATA(sess)
            }
        }
    }
}
