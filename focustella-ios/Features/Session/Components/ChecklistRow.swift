// 📂 Features/Session/Components/ChecklistRow.swift
import SwiftUI

struct ChecklistRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isCompleted ? .blue : .gray.opacity(0.5))
                    .scaleEffect(item.isCompleted ? 1.1 : 1.0)
                
                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundColor(item.isCompleted ? .gray : .primary)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
