// 📂 Domain/UseCases/SearchUsersUseCase.swift
import Foundation

struct SearchUsersUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository = UserRepositoryImpl()) {
        self.repository = repository
    }
    
    func execute(keyword: String) async throws -> [UserSearchDTO] {
        let dtos = try await repository.searchUsers(keyword: keyword)
        
        // 서버 DTO를 뷰에서 쓰기 좋은 모델로 변환
        return dtos.map {
            UserSearchDTO(id: $0.id, nickname: $0.nickname, userCode: $0.userCode)
        }
    }
}
