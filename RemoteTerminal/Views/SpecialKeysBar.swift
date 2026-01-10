import SwiftUI

struct SpecialKeysBar: View {
    let onKeyPress: (String) -> Void
    var onToggleScrollMode: (() -> Void)? = nil
    @Binding var isScrollModeEnabled: Bool

    @ObservedObject private var settings = KeyBarSettings.shared
    @State private var showSettings = false

    init(onKeyPress: @escaping (String) -> Void,
         onToggleScrollMode: (() -> Void)? = nil,
         isScrollModeEnabled: Binding<Bool> = .constant(true)) {
        self.onKeyPress = onKeyPress
        self.onToggleScrollMode = onToggleScrollMode
        self._isScrollModeEnabled = isScrollModeEnabled
    }

    var body: some View {
        HStack(spacing: 0) {
            // 按键滚动区域
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(settings.enabledKeys) { key in
                        SpecialKeyButton(key: key) {
                            onKeyPress(key.escapeSequence)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            // 右侧功能按钮
            HStack(spacing: 4) {
                Divider()
                    .frame(height: 28)

                // 滚动模式切换按钮
                if onToggleScrollMode != nil {
                    Button {
                        onToggleScrollMode?()
                    } label: {
                        Image(systemName: isScrollModeEnabled ? "hand.draw.fill" : "hand.draw")
                            .font(.system(size: 16))
                            .foregroundStyle(isScrollModeEnabled ? .blue : .primary)
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                // 设置按钮
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .sheet(isPresented: $showSettings) {
            KeyBarSettingsView()
        }
    }
}

struct SpecialKeyButton: View {
    let key: KeyItem
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(key.label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(key.isCustom ? .blue : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 设置视图

struct KeyBarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = KeyBarSettings.shared
    @State private var showAddCustomKey = false
    @State private var customKeyInput = ""
    @State private var showInvalidAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("当前启用的按键") {
                    ForEach(settings.enabledKeys) { key in
                        HStack {
                            Text(key.label)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(key.isCustom ? .blue : .primary)
                                .frame(width: 60, alignment: .leading)
                            if key.isCustom {
                                Text("自定义")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            } else if let presetType = key.presetType,
                                      let preset = SpecialKeyType(rawValue: presetType) {
                                Text(preset.displayName)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        settings.enabledKeys.remove(atOffsets: indexSet)
                    }
                    .onMove { source, destination in
                        settings.moveKey(from: source, to: destination)
                    }
                }

                Section("添加自定义按键") {
                    HStack {
                        TextField("输入组合键 (如 Ctrl+Shift+W)", text: $customKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                        Button {
                            addCustomKey()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        }
                        .disabled(customKeyInput.isEmpty)
                    }

                    Text("支持格式: Ctrl+A, Ctrl+Shift+W, Alt+F1 等")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("添加预设按键") {
                    ForEach(availablePresets) { preset in
                        Button {
                            settings.addPresetKey(preset)
                        } label: {
                            HStack {
                                Text(preset.rawValue)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 60, alignment: .leading)
                                Text(preset.displayName)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button("恢复默认设置") {
                        settings.resetToDefault()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("自定义按键")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("无效的按键组合", isPresented: $showInvalidAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请输入有效的按键组合，如 Ctrl+A 或 Ctrl+Shift+W")
            }
        }
    }

    private var availablePresets: [SpecialKeyType] {
        SpecialKeyType.allCases.filter { preset in
            !settings.enabledKeys.contains(where: { $0.presetType == preset.rawValue })
        }
    }

    private func addCustomKey() {
        if settings.addCustomKeyFromCombo(customKeyInput) {
            customKeyInput = ""
        } else {
            showInvalidAlert = true
        }
    }
}

#Preview {
    VStack {
        Spacer()
        SpecialKeysBar(
            onKeyPress: { key in print("Pressed: \(key)") }
        )
    }
}
