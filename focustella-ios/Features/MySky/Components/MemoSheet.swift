import SwiftUI

struct MemoSheet: View {
    let onSave: (SessionMemo) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = MemoSheetViewModel()

    @State private var selectedTags: Set<String> = []
    @State private var rating: Int = 4
    @State private var freeText: String = ""
    @State private var newTagName: String = ""
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("무엇을 공부했나요?") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.tags, id: \.self) { tag in
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

                    HStack {
                        TextField("새 태그 추가", text: $newTagName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("추가") {
                            Task { await addTag() }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoadingTags)
                    }
                }

                if !viewModel.tags.isEmpty {
                    Section("태그 관리") {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                Button(role: .destructive) {
                                    Task { await deleteTag(tag) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
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

                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
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
                        Task { await saveMemo() }
                    }
                    .disabled(selectedTags.isEmpty || isSaving)
                }
            }
            .task {
                await viewModel.loadTagsIfNeeded()
            }
        }
    }

    @MainActor
    private func addTag() async {
        if let created = await viewModel.addTag(name: newTagName) {
            selectedTags.insert(created)
            newTagName = ""
        }
    }

    @MainActor
    private func deleteTag(_ tag: String) async {
        await viewModel.deleteTag(tag)
        selectedTags.remove(tag)
    }

    @MainActor
    private func saveMemo() async {
        isSaving = true
        saveErrorMessage = nil
        let memo = SessionMemo(
            topicTags: Array(selectedTags).sorted(),
            rating: rating,
            freeText: freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : freeText
        )
        let didSave = await onSave(memo)
        isSaving = false
        if didSave {
            dismiss()
        } else {
            saveErrorMessage = "메모 저장에 실패했습니다. 네트워크 상태를 확인하고 다시 시도해주세요."
        }
    }
}
