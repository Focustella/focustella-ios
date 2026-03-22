import Foundation

private struct EmptyPayload: Decodable {}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeBlock = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send<Response: Decodable>(_ responseType: Response.Type = Response.self, endpoint: Endpoint) async throws -> Response {
            let request = try makeRequest(for: endpoint)
            let startedAt = Date()
            NetworkLogger.request(request, requiresAuth: endpoint.requiresAuth)

            do {
                let (data, response) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startedAt)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIClientError.invalidResponse
                }

                NetworkLogger.response(request: request, statusCode: httpResponse.statusCode, elapsed: elapsed, data: data)

                // 1. 에러 상태코드 (400, 500 등) 처리
                guard (200...299).contains(httpResponse.statusCode) else {
                    let serverEnvelope = try? decoder.decode(APIEnvelope<EmptyPayload>.self, from: data)
                    throw APIClientError.server(
                        statusCode: httpResponse.statusCode,
                        code: serverEnvelope?.error?.code,
                        message: serverEnvelope?.error?.message
                    )
                }

                // 🔥 [핵심 추가 포인트] 데이터가 아예 없거나, 빈 응답(EmptyAPIResponse 등)을 기대하는 경우 예외 처리
                if data.isEmpty || Response.self == EmptyAPIResponse.self {
                    if let emptyResponse = EmptyAPIResponse() as? Response {
                        NetworkLogger.decoded(request: request, payloadType: Response.self, data: data)
                        return emptyResponse
                    }
                }

                // 2. 정상 상태이고 데이터가 있을 때만 디코딩 시도
                let envelope = try decoder.decode(APIEnvelope<Response>.self, from: data)
                guard envelope.success, let payload = envelope.data else {
                    throw APIClientError.server(
                        statusCode: httpResponse.statusCode,
                        code: envelope.error?.code,
                        message: envelope.error?.message
                    )
                }

                NetworkLogger.decoded(request: request, payloadType: Response.self, data: data)
                return payload
                
            } catch {
                NetworkLogger.error(request: request, error: error)
                throw error
            }
        }

    private func makeRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let baseURL = Self.baseURL else {
            throw APIClientError.invalidBaseURL
        }

        let endpointURL = baseURL.appendingPathComponent(endpoint.path)
        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        guard let url = components?.url else {
            throw APIClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth {
            guard let token = AuthSessionStore.accessToken else {
                throw APIClientError.missingAuthToken
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        endpoint.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

//    private static var baseURL: URL? {
//        let raw = infoPlistBaseURL() ?? bundledSecretsBaseURL() ?? ""
//        let normalized = raw
//            .replacingOccurrences(of: "\\/", with: "/")
//            .replacingOccurrences(of: "'", with: "")
//            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//
//        guard !normalized.isEmpty else { return nil }
//
//        if normalized.hasSuffix("/api/v1"), let url = URL(string: normalized) {
//            return url
//        }
//
//        return URL(string: normalized)?
//            .appendingPathComponent("api")
//            .appendingPathComponent("v1")
//    }
    // 📂 Network/APIClient/APIClient.swift

        private static var baseURL: URL? {
            // 🔥 1. 개발자 모드가 켜져 있는지 확인! (우선순위 1등)
            let isDeveloperMode = UserDefaults.standard.bool(forKey: "developerMode")
            
            if isDeveloperMode {
                // 사용자가 입력한 IP 주소 가져오기
                let serverIP = UserDefaults.standard.string(forKey: "serverIP")?.trimmingCharacters(in: .whitespaces) ?? ""
                
                let customURLString: String
                if serverIP.isEmpty || serverIP == "localhost" {
                    customURLString = "http://localhost:8080/api/v1"
                } else {
                    customURLString = "http://\(serverIP):8080/api/v1"
                }
                
                print("🔧 [APIClient] 개발자 모드 ON - 커스텀 URL 사용: \(customURLString)")
                return URL(string: customURLString)
            }
            
            // 🔥 2. 개발자 모드가 꺼져있다면 기존처럼 파일(Secrets 등)에서 읽어옵니다.
            let raw = infoPlistBaseURL() ?? bundledSecretsBaseURL() ?? ""
            let normalized = raw
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "'", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalized.isEmpty else { return nil }

            if normalized.hasSuffix("/api/v1"), let url = URL(string: normalized) {
                return url
            }

            return URL(string: normalized)?
                .appendingPathComponent("api")
                .appendingPathComponent("v1")
        }

    private static func infoPlistBaseURL() -> String? {
        (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bundledSecretsBaseURL() -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "xcconfig"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("BASE_URL") else { continue }
            guard let value = line.split(separator: "=", maxSplits: 1).last else { continue }
            return String(value).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
