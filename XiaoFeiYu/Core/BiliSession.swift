import Foundation

/// B站 SESSDATA 双层级：用户登录号优先，未登录回落到内置号。
final class BiliSession {
    static let shared = BiliSession()

#if SHARED_VERSION
    /// Shared：内置大会员 SESSDATA，仅自己使用
    let defaultSessdata = "574a8a2a%2C1809368862%2C7f1a7%2Ab1CjBTOs5w_DU3T-wBhLeudzk58BOMQJkF3dylRd9a_5XzzOLHaFq3D1t4u5KHOMZLRB0SVkxUbWtMNk14UVd0ek45cUUtUDh3U2VuSjNPMnFsLWFUTGdoQVBfZXUtQUU4OW5sd0owRGx3UG5LRFB6NFVRTlVRMlhLelQ2NFdHb1NhOEFjQkgyYkNRIIEC"
#else
    /// Clean：绝不内置账号，用户必须自己登录
    let defaultSessdata = ""
#endif

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
