import Foundation

/// B站 SESSDATA 双层级：用户登录号优先，未登录回落到内置号。
final class BiliSession {
    static let shared = BiliSession()

    /// 内置默认账号；留空 = 不启用内置兜底。填入自己的大会员 SESSDATA。
    let defaultSessdata = ""

    private let key = "bili_sessdata"
    private let defaults = UserDefaults.standard

    private init() {}

    var userSessdata: String {
        defaults.string(forKey: key) ?? ""
    }

    var effectiveSessdata: String {
        let user = userSessdata.trimmingCharacters(in: .whitespacesAndNewlines)
        return user.isEmpty ? defaultSessdata : user
    }

    var isUsingDefault: Bool {
        userSessdata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !defaultSessdata.isEmpty
    }

    func saveUser(_ value: String) {
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key)
    }

    /// 只清用户号，不动 defaultSessdata。
    func logoutUser() {
        defaults.removeObject(forKey: key)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
