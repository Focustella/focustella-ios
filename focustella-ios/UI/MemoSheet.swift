import SwiftUI

struct MemoSheet: View {
    let onSave: (SessionMemo) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTags: Set<String> = []
    @State private var rating: Int = 4
    @State private var freeText: String = ""

    private let tags = ["Swift", "iOS", "알고리즘", "독해", "문제풀이", "리뷰", "기획", "디버깅"]

    var body: some View {
        NavigationStack {
            Form {
                Section("무엇을 공부했나요?") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Button {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                } label: {
                                    Text(tag)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.16), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Text("최소 1개 선택")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("성취도") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .onTapGesture { rating = value }
                        }
                    }
                }

                Section("자유 메모 (선택)") {
                    TextEditor(text: $freeText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("세션 메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let memo = SessionMemo(
                            topicTags: Array(selectedTags).sorted(),
                            rating: rating,
                            freeText: freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : freeText
                        )
                        onSave(memo)
                        dismiss()
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
    }
}
