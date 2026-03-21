import Foundation

protocol SkyRepository {
    func fetchMySky() async throws -> SkyResponseDTO
    func fetchSky(userId: String) async throws -> SkyResponseDTO
}
