import Foundation

struct AuthSessionStore {
    private static let accessTokenKey = "accessToken"
    private static let userIdKey = "userId"
    private static let userSeedKey = "userSeed"

    static var accessToken: String? {
        let token = UserDefaults.standard.string(forKey: accessTokenKey) ?? ""
        return token.isEmpty ? nil : token
    }

    static func save(accessToken: String, userId: String, seed: Int64) {
        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: accessTokenKey)
        defaults.set(userId, forKey: userIdKey)
        defaults.set(seed, forKey: userSeedKey)
        defaults.set(true, forKey: "isLoggedIn")
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: accessTokenKey)
        defaults.removeObject(forKey: userIdKey)
        defaults.removeObject(forKey: userSeedKey)
        defaults.set(false, forKey: "isLoggedIn")
    }
}
