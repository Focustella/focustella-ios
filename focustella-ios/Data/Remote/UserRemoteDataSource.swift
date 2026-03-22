// 📂 Network/DataSources/UserRemoteDataSource.swift
import Foundation

protocol UserRemoteDataSource {
    func searchUsers(keyword: String) async throws -> [UserSearchDTO]
}
