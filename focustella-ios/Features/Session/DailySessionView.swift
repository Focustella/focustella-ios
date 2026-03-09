import SwiftUI

// MARK: - DailySessionView (바텀 시트 모디파이어 추가)
struct DailySessionView: View {
    @StateObject private var viewModel = DailySessionViewModel()
    
    @State private var showingAddTemplate = false
    @State private var templateToEdit: ChecklistTemplate?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSessionActive {
                    ActiveSessionView(viewModel: viewModel)
                } else {
                    TemplateSelectionView(
                        viewModel: viewModel,
                        showingAddTemplate: $showingAddTemplate,
                        templateToEdit: $templateToEdit
                    )
                }
            }
            .navigationTitle(viewModel.isSessionActive ? "세션 진행 중" : "일일 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.isSessionActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddTemplate = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert("안내", isPresented: $viewModel.showCompletionAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("오늘의 체크리스트를 완료했어요!")
            }
            .sheet(isPresented: $showingAddTemplate) {
                AddTemplateView(viewModel: viewModel)
            }
            .sheet(item: $templateToEdit) { template in
                EditTemplateView(viewModel: viewModel, template: template)
            }
        }
        // 🔥 바텀 시트를 위한 핵심 모디파이어 2가지
        .presentationDetents([.medium, .large]) // 화면의 절반(.medium) 및 전체(.large) 높이 지원
        .presentationDragIndicator(.visible)    // 사용자가 아래로 당겨서 닫을 수 있음을 알리는 상단 핸들(손잡이) 표시
    }
}

// 진행 중인 일일 세션 뷰 (항목 추가 기능 포함)
struct ActiveSessionView: View {
    @ObservedObject var viewModel: DailySessionViewModel
    
    // 🔥 텍스트 입력을 받기 위한 상태 변수 추가
    @State private var newItemTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: viewModel.progress)
                .tint(.blue)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.progress)
            
            ScrollView {
                VStack(spacing: 12) {
                    // 기존 진행 중인 항목 리스트
                    ForEach(viewModel.activeItems) { item in
                        ChecklistRow(item: item) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.toggleItem(id: item.id)
                            }
                        }
                    }
                    
                    // 🔥 세션 도중 항목 추가 UI
                    HStack(spacing: 16) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.6))
                        
                        TextField("세션 중 새로운 할 일 추가...", text: $newItemTitle)
                            .font(.system(size: 16, weight: .medium))
                            .onSubmit {
                                addNewItem()
                            }
                        
                        Spacer()
                        
                        // 입력값이 있을 때만 나타나는 추가 버튼
                        if !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: addNewItem) {
                                Text("추가")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            // 버튼이 나타날 때 부드러운 애니메이션
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                    )
                    // 애니메이션 효과 적용
                    .animation(.easeInOut(duration: 0.2), value: newItemTitle)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: {
                Task { await viewModel.completeDailySession() }
            }) {
                Text("완료하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!viewModel.canComplete)
            .padding()
        }
    }
    
    // 🔥 항목 추가 실행 로직
    private func addNewItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 아이템이 추가될 때 리스트가 부드럽게 늘어나도록 애니메이션 적용
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.addActiveItem(title: newItemTitle)
            newItemTitle = "" // 입력창 초기화
        }
    }
}

// 감성있는 커스텀 체크박스 뷰 (변경 없음)
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

// TemplateSelectionView (변경 없음)
struct TemplateSelectionView: View {
    @ObservedObject var viewModel: DailySessionViewModel
    @Binding var showingAddTemplate: Bool
    @Binding var templateToEdit: ChecklistTemplate?
    
    var body: some View {
        List {
            Section(header: Text("내 템플릿")) {
                ForEach(viewModel.templates) { template in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { viewModel.expandedTemplateID == template.id },
                            set: { isExpanded in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.expandedTemplateID = isExpanded ? template.id : nil
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(template.items) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .font(.system(size: 12))
                                    Text(item.title)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Button(action: { templateToEdit = template }) {
                                    Text("수정")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                                
                                Button(action: {
                                    withAnimation {
                                        viewModel.startSession(with: template)
                                    }
                                }) {
                                    Text("진행")
                                        .font(.subheadline)
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(template.items.count)개의 항목")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.gray)
                }
                .onDelete(perform: viewModel.deleteTemplate)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// 새 템플릿 추가 뷰 (변경 없음)
struct AddTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DailySessionViewModel
    
    @State private var templateName = ""
    @State private var newItemTitle = ""
    @State private var items: [ChecklistItem] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("템플릿 이름") {
                    TextField("예: 주말 모드", text: $templateName)
                }
                
                Section("체크리스트 항목") {
                    ForEach(items) { item in
                        Text(item.title)
                    }
                    .onDelete { indexSet in
                        items.remove(atOffsets: indexSet)
                    }
                    
                    HStack {
                        TextField("할 일 추가", text: $newItemTitle)
                        Button("추가") {
                            guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            items.append(ChecklistItem(title: newItemTitle))
                            newItemTitle = ""
                        }
                    }
                }
            }
            .navigationTitle("새 템플릿 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let newTemplate = ChecklistTemplate(name: templateName, items: items)
                        viewModel.addTemplate(newTemplate)
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || items.isEmpty)
                }
            }
        }
    }
}

// 기존 템플릿 수정 뷰 (변경 없음)
struct EditTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DailySessionViewModel
    
    let originalTemplate: ChecklistTemplate
    
    @State private var templateName: String
    @State private var items: [ChecklistItem]
    @State private var newItemTitle = ""
    
    init(viewModel: DailySessionViewModel, template: ChecklistTemplate) {
        self.viewModel = viewModel
        self.originalTemplate = template
        _templateName = State(initialValue: template.name)
        _items = State(initialValue: template.items)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("템플릿 이름") {
                    TextField("예: 주말 모드", text: $templateName)
                }
                
                Section("체크리스트 항목") {
                    ForEach(items) { item in
                        Text(item.title)
                    }
                    .onDelete { indexSet in
                        items.remove(atOffsets: indexSet)
                    }
                    
                    HStack {
                        TextField("할 일 추가", text: $newItemTitle)
                        Button("추가") {
                            guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            items.append(ChecklistItem(title: newItemTitle))
                            newItemTitle = ""
                        }
                    }
                }
            }
            .navigationTitle("템플릿 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let updated = ChecklistTemplate(id: originalTemplate.id, name: templateName, items: items)
                        viewModel.updateTemplate(updated)
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || items.isEmpty)
                }
            }
        }
    }
}

// MARK: - App Entry / Preview
struct HomeView: View {
    @State private var showDailySession = false
    
    var body: some View {
        VStack {
            Text("Focustella 홈 화면")
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                showDailySession = true
            }) {
                Text("일일 세션 시작하기")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        // 👉 fullScreenCover 대신 sheet 를 사용하여 바텀 시트로 띄웁니다.
        .sheet(isPresented: $showDailySession) {
            DailySessionView()
        }
    }
}

#Preview {
    HomeView()
}
