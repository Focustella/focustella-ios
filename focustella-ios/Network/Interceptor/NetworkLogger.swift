import Foundation
import os

enum NetworkLogger {
    private static let logger = Logger(subsystem: "focustella-ios", category: "Network")

    static func request(_ request: URLRequest, requiresAuth: Bool) {
        logger.notice("[REQ] \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) auth=\(requiresAuth, privacy: .public) body=\(preview(request.httpBody), privacy: .public)")
    }

    static func response(request: URLRequest, statusCode: Int, elapsed: TimeInterval, data: Data?) {
        logger.notice("[RES] \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) status=\(statusCode, privacy: .public) elapsed=\(String(format: "%.3f", elapsed), privacy: .public)s body=\(preview(data), privacy: .public)")
    }

    static func decoded<Response>(request: URLRequest, payloadType: Response.Type, data: Data?) {
        logger.notice("[DEC] \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) payload=\(String(describing: payloadType), privacy: .public) data=\(preview(data), privacy: .public)")
    }

    static func error(request: URLRequest, error: Error) {
        logger.error("[ERR] \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }

    private static func preview(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "-" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let pretty = String(data: prettyData, encoding: .utf8) {
            return clamp(pretty)
        }

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        return clamp(raw)
    }

    private static func clamp(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\n", with: " ")
        return normalized.count > 800 ? String(normalized.prefix(800)) + "..." : normalized
    }
}
