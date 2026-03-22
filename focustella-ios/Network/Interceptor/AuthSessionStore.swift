// 📂 Network/Interceptor/AuthSessionStore.swift
import Foundation

struct AuthSessionStore {
    private static let accessTokenKey = "accessToken"
    private static let userIdKey = "userId"
    private static let userSeedKey = "userSeed"
    // 🔥 1. 닉네임과 유저코드 키 추가
    private static let nicknameKey = "nickname"
    private static let userCodeKey = "userCode"

    static var accessToken: String? {
        let token = UserDefaults.standard.string(forKey: accessTokenKey) ?? ""
        return token.isEmpty ? nil : token
    }
    
    // 🔥 2. 저장된 내 정보 불러오기
    static var myNickname: String {
        UserDefaults.standard.string(forKey: nicknameKey) ?? "이름없음"
    }
    static var myUserCode: String {
        UserDefaults.standard.string(forKey: userCodeKey) ?? "00000000"
    }

    // 🔥 3. 저장 함수 파라미터에 닉네임과 유저코드 추가!
    static func save(accessToken: String, userId: String, seed: Int64, nickname: String?, userCode: String?) {
        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: accessTokenKey)
        defaults.set(userId, forKey: userIdKey)
        defaults.set(seed, forKey: userSeedKey)
        defaults.set(nickname, forKey: nicknameKey) // 닉네임 저장
        defaults.set(userCode, forKey: userCodeKey) // 유저코드 저장
        defaults.set(true, forKey: "isLoggedIn")
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: accessTokenKey)
        defaults.removeObject(forKey: userIdKey)
        defaults.removeObject(forKey: userSeedKey)
        defaults.removeObject(forKey: nicknameKey) // 닉네임 삭제
        defaults.removeObject(forKey: userCodeKey) // 유저코드 삭제
        defaults.set(false, forKey: "isLoggedIn")
    }
}
