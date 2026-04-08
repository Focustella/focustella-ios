import Foundation
import CoreGraphics

enum LogJSONFormatter {
    static func pretty(_ object: Any, maxLength: Int = 4_000) -> String {
        render(object, options: [.prettyPrinted, .sortedKeys], maxLength: maxLength, preserveNewlines: true)
    }

    static func compact(_ object: Any, maxLength: Int = 1_200) -> String {
        render(object, options: [.sortedKeys], maxLength: maxLength, preserveNewlines: false)
    }

    static func point(_ point: CGPoint, precision: Int = 3) -> [String: Double] {
        [
            "x": rounded(point.x, precision: precision),
            "y": rounded(point.y, precision: precision)
        ]
    }

    private static func render(
        _ object: Any,
        options: JSONSerialization.WritingOptions,
        maxLength: Int,
        preserveNewlines: Bool
    ) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: options),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: object)
        }

        return clamp(text, maxLength: maxLength, preserveNewlines: preserveNewlines)
    }

    private static func clamp(_ value: String, maxLength: Int, preserveNewlines: Bool) -> String {
        let normalized = preserveNewlines ? value : value.replacingOccurrences(of: "\n", with: " ")
        guard normalized.count > maxLength else { return normalized }

        let clipped = String(normalized.prefix(maxLength))
        return preserveNewlines ? "\(clipped)\n..." : "\(clipped)..."
    }

    private static func rounded(_ value: CGFloat, precision: Int) -> Double {
        let scale = pow(10.0, Double(max(0, precision)))
        return (Double(value) * scale).rounded() / scale
    }
}
