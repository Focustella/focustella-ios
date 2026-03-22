// 📂 Domain/Repositories/UserRepository.swift (인터페이스와 구현체)
import Foundation

protocol UserRepository {
    func searchUsers(keyword: String) async throws -> [UserSearchDTO]
}

final class UserRepositoryImpl: UserRepository {
    private let remoteDataSource: UserRemoteDataSource
    
    init(remoteDataSource: UserRemoteDataSource = UserRemoteDataSourceImpl()) {
        self.remoteDataSource = remoteDataSource
    }
    
    func searchUsers(keyword: String) async throws -> [UserSearchDTO] {
        return try await remoteDataSource.searchUsers(keyword: keyword)
    }
}
