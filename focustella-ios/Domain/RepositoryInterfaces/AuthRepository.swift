import Foundation

protocol AuthRepository {
    func authenticateAnonymously() async throws -> AnonymousAuthData
}
