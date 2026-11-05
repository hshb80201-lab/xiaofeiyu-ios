import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessdata = BiliSession.shared.userSessdata
    @State private var showLogin = false
    @State private var showDisclaimer = false

    var body: some View {
        NavigationStack {
            List {
                Section("B站账号") {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(sessdata.isEmpty ? "登录我的账号" : "切换我的账号") {
                        showLogin = true
                    }

                    if !sessdata.isEmpty {
                        Button("退出登录（恢复默认）", role: .destructive) {
                            BiliSession.shared.logoutUser()
                            sessdata = ""
                        }
                    }
                }

#if SHOW_DISCLAIMER
                Section {
                    Text("开发者：\(AboutInfo.author)")
                        .font(.footnote)
                    Text(AboutInfo.copyright)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("查看免责声明") {
                        showDisclaimer = true
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text(AboutInfo.copyright)
                        .font(.caption2)
                }
#endif
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showLogin) {
                BiliLoginSheet { sess in
                    sessdata = sess
                }
            }
#if SHOW_DISCLAIMER
            .sheet(isPresented: $showDisclaimer) {
                NavigationStack {
                    ScrollView {
                        Text(AboutInfo.disclaimer)
                            .font(.body)
                            .padding(20)
                    }
                    .navigationTitle("免责声明")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("我知道了") { showDisclaimer = false }
                        }
                    }
                }
            }
#endif
        }
    }

    private var statusText: String {
        if !sessdata.isEmpty { return "当前使用：我的 B站账号" }
        if !BiliSession.shared.defaultSessdata.isEmpty {
            return "当前使用：内置默认账号"
        }
        return "当前使用：未配置账号（未登录仅 720P）"
    }
}
