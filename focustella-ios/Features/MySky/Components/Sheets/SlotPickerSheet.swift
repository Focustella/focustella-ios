import SwiftUI
import os

struct SlotPickerSheet: View {
    private static let logger = Logger(subsystem: "focustella-ios", category: "FocusSession")
    let onSelect: (Int) -> Void
    private let minimumSeconds = 5 * 60

    @Environment(\.dismiss) private var dismiss

    private let templates: [(title: String, seconds: Int)] = [
        ("5분", 5 * 60),
        ("10분", 10 * 60),
        ("30분", 30 * 60),
        ("1시간", 60 * 60),
        ("2시간", 2 * 60 * 60),
        ("4시간", 4 * 60 * 60),
        ("6시간", 6 * 60 * 60)
    ]
    @State private var totalSeconds: Int = 5 * 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(templates, id: \.seconds) { template in
                        let isSelected = totalSeconds == template.seconds
                        Button {
                            applyTemplate(template.seconds)
                        } label: {
                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    isSelected ? Color.white : Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(
                    Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                CountdownColonPicker(totalSeconds: $totalSeconds)
                .frame(height: 170)
                .padding(6)
                .background(
                    Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                Button {
                    let selectedSeconds = max(minimumSeconds, totalSeconds)
                    Self.logger.notice("slot picker start tapped. selectedSeconds=\(selectedSeconds, privacy: .public)")
                    print("🛰️ [FocusSession] SlotPicker start tapped. selectedSeconds=\(selectedSeconds)")
                    onSelect(selectedSeconds)
                    dismiss()
                } label: {
                    Text("시작하기")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Color.white,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(totalSeconds == 0)
                .opacity(totalSeconds == 0 ? 0.5 : 1)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("집중 시간")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Self.logger.notice("slot picker appeared")
                applyTemplate(5 * 60)
            }
        }
        .presentationDetents([.height(420)])
    }

    private func applyTemplate(_ seconds: Int) {
        totalSeconds = (max(minimumSeconds, seconds) / (5 * 60)) * (5 * 60)
    }
}

private struct CountdownColonPicker: UIViewRepresentable {
    @Binding var totalSeconds: Int
    private let minuteSteps = Array(stride(from: 0, through: 55, by: 5))

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        picker.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        context.coordinator.applySelection(on: picker, totalSeconds: totalSeconds)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.applySelection(on: uiView, totalSeconds: totalSeconds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(totalSeconds: $totalSeconds, minuteSteps: minuteSteps)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        @Binding var totalSeconds: Int
        let minuteSteps: [Int]
        private let maxHour: Int = 12

        init(totalSeconds: Binding<Int>, minuteSteps: [Int]) {
            self._totalSeconds = totalSeconds
            self.minuteSteps = minuteSteps
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return maxHour + 1
            case 1: return 1
            default: return minuteSteps.count
            }
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            44
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            let total = max(0, pickerView.bounds.width - pickerView.layoutMargins.left - pickerView.layoutMargins.right)
            switch component {
            case 1: return 28
            default: return (total - 28) / 2
            }
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 21, weight: .regular)
            label.textColor = .white

            switch component {
            case 0:
                label.text = String(format: "%02d", row)
            case 1:
                label.text = ":"
                label.font = .systemFont(ofSize: 21, weight: .semibold)
            default:
                label.text = String(format: "%02d", minuteSteps[row])
            }
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard component != 1 else { return }
            let hour = pickerView.selectedRow(inComponent: 0)
            let minute = minuteSteps[pickerView.selectedRow(inComponent: 2)]
            totalSeconds = max(5 * 60, (hour * 3600) + (minute * 60))
        }

        func applySelection(on pickerView: UIPickerView, totalSeconds: Int) {
            let clamped = max(5 * 60, totalSeconds)
            let hour = min(maxHour, clamped / 3600)
            let minute = (clamped % 3600) / 60
            let snappedMinute = (minute / 5) * 5
            let minuteIndex = minuteSteps.firstIndex(of: snappedMinute) ?? 0

            if pickerView.selectedRow(inComponent: 0) != hour {
                pickerView.selectRow(hour, inComponent: 0, animated: false)
            }
            if pickerView.selectedRow(inComponent: 1) != 0 {
                pickerView.selectRow(0, inComponent: 1, animated: false)
            }
            if pickerView.selectedRow(inComponent: 2) != minuteIndex {
                pickerView.selectRow(minuteIndex, inComponent: 2, animated: false)
            }
        }
    }
}
